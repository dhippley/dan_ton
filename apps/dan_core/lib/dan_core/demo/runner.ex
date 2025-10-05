defmodule DanCore.Demo.Runner do
  @moduledoc """
  GenServer that orchestrates demo execution.

  Manages demo state, executes steps via Playwright bridge, and broadcasts
  events via PubSub for real-time UI updates.
  """

  use GenServer
  require Logger

  alias DanCore.Demo.Parser
  alias Phoenix.PubSub

  @pubsub_topic "demo:runner"

  defmodule State do
    @moduledoc false
    defstruct [
      :scenario,
      :current_step_index,
      :status,
      :playwright_port,
      step_history: [],
      env: %{}
    ]

    @type t :: %__MODULE__{
            scenario: Parser.scenario() | nil,
            current_step_index: non_neg_integer() | nil,
            status: :idle | :running | :paused | :completed | :error,
            playwright_port: port() | nil,
            step_history: list(map()),
            env: map()
          }
  end

  # Client API

  @doc """
  Starts the DemoRunner GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Loads and starts a demo from a script file.
  """
  @spec start_demo(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def start_demo(script_path) do
    GenServer.call(__MODULE__, {:start_demo, script_path})
  end

  @doc """
  Executes the next step in the demo.
  """
  @spec next_step() :: :ok | {:error, String.t()}
  def next_step do
    GenServer.call(__MODULE__, :next_step)
  end

  @doc """
  Goes back to the previous step.
  """
  @spec previous_step() :: :ok | {:error, String.t()}
  def previous_step do
    GenServer.call(__MODULE__, :previous_step)
  end

  @doc """
  Executes recovery steps.
  """
  @spec recover() :: :ok | {:error, String.t()}
  def recover do
    GenServer.call(__MODULE__, :recover)
  end

  @doc """
  Restarts the demo from the beginning.
  """
  @spec restart() :: :ok | {:error, String.t()}
  def restart do
    GenServer.call(__MODULE__, :restart)
  end

  @doc """
  Stops the current demo and resets state.
  """
  @spec stop_demo() :: :ok
  def stop_demo do
    GenServer.call(__MODULE__, :stop_demo)
  end

  @doc """
  Returns the current demo state.
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %State{
      status: :idle,
      current_step_index: nil,
      scenario: nil,
      playwright_port: nil,
      step_history: [],
      env: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_demo, script_path}, _from, state) do
    case Parser.parse_file(script_path) do
      {:ok, scenario} ->
        Logger.info("Starting demo: #{scenario.name}")

        new_state = %{
          state
          | scenario: scenario,
            current_step_index: 0,
            status: :running,
            step_history: [],
            env: scenario.env
        }

        broadcast_event(:demo_started, %{
          name: scenario.name,
          total_steps: length(scenario.steps)
        })

        {:reply, {:ok, scenario.name}, new_state}

      {:error, reason} ->
        Logger.error("Failed to start demo: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:next_step, _from, %State{scenario: nil} = state) do
    {:reply, {:error, "No demo loaded"}, state}
  end

  def handle_call(:next_step, _from, %State{} = state) do
    steps = state.scenario.steps
    next_index = (state.current_step_index || -1) + 1

    if next_index < length(steps) do
      step = Enum.at(steps, next_index)

      case execute_step(step, state) do
        {:ok, result} ->
          new_state = %{
            state
            | current_step_index: next_index,
              step_history: state.step_history ++ [{next_index, step, result}]
          }

          broadcast_event(:step_executed, %{
            step_index: next_index,
            step: step,
            result: result,
            total_steps: length(steps)
          })

          # Check if demo is complete
          new_state =
            if next_index == length(steps) - 1 do
              broadcast_event(:demo_completed, %{name: state.scenario.name})
              %{new_state | status: :completed}
            else
              new_state
            end

          {:reply, :ok, new_state}

        {:error, reason} ->
          Logger.error("Step execution failed: #{reason}")

          new_state = %{state | status: :error}

          broadcast_event(:step_failed, %{
            step_index: next_index,
            step: step,
            error: reason
          })

          {:reply, {:error, reason}, new_state}
      end
    else
      {:reply, {:error, "No more steps"}, state}
    end
  end

  @impl true
  def handle_call(:previous_step, _from, %State{scenario: nil} = state) do
    {:reply, {:error, "No demo loaded"}, state}
  end

  def handle_call(:previous_step, _from, %State{current_step_index: nil} = state) do
    {:reply, {:error, "No step to go back to"}, state}
  end

  def handle_call(:previous_step, _from, %State{current_step_index: 0} = state) do
    {:reply, {:error, "Already at first step"}, state}
  end

  def handle_call(:previous_step, _from, state) do
    prev_index = state.current_step_index - 1
    new_state = %{state | current_step_index: prev_index}

    broadcast_event(:step_changed, %{
      step_index: prev_index,
      direction: :backward
    })

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:recover, _from, %State{scenario: nil} = state) do
    {:reply, {:error, "No demo loaded"}, state}
  end

  def handle_call(:recover, _from, state) do
    recover_steps = state.scenario.recover

    if Enum.empty?(recover_steps) do
      {:reply, {:error, "No recovery steps defined"}, state}
    else
      Logger.info("Executing recovery steps")

      results =
        Enum.map(recover_steps, fn step ->
          execute_step(step, state)
        end)

      errors = Enum.filter(results, fn result -> match?({:error, _}, result) end)

      if Enum.empty?(errors) do
        broadcast_event(:recovery_completed, %{steps: length(recover_steps)})
        new_state = %{state | status: :running}
        {:reply, :ok, new_state}
      else
        {:reply, {:error, "Recovery failed"}, state}
      end
    end
  end

  @impl true
  def handle_call(:restart, _from, %State{scenario: nil} = state) do
    {:reply, {:error, "No demo loaded"}, state}
  end

  def handle_call(:restart, _from, state) do
    Logger.info("Restarting demo: #{state.scenario.name}")

    new_state = %{
      state
      | current_step_index: 0,
        status: :running,
        step_history: []
    }

    broadcast_event(:demo_restarted, %{name: state.scenario.name})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:stop_demo, _from, state) do
    Logger.info("Stopping demo")

    # Close Playwright port if open
    if state.playwright_port do
      Port.close(state.playwright_port)
    end

    new_state = %State{
      status: :idle,
      current_step_index: nil,
      scenario: nil,
      playwright_port: nil,
      step_history: [],
      env: %{}
    }

    broadcast_event(:demo_stopped, %{})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state_map = %{
      status: state.status,
      current_step_index: state.current_step_index,
      scenario_name: state.scenario && state.scenario.name,
      total_steps: state.scenario && length(state.scenario.steps),
      step_history: Enum.map(state.step_history, fn {idx, step, result} ->
        %{index: idx, step: step, result: result}
      end)
    }

    {:reply, state_map, state}
  end

  # Private Functions

  defp execute_step(%{type: type} = step, _state) do
    Logger.info("Executing step: #{type}")

    # For now, simulate execution
    # In a real implementation, this would communicate with Playwright bridge
    case type do
      "goto" ->
        {:ok, %{action: "goto", url: step.params}}

      "click" ->
        {:ok, %{action: "click", target: step.params}}

      "fill" ->
        {:ok, %{action: "fill", field: step.params}}

      "assert_text" ->
        {:ok, %{action: "assert_text", text: step.params}}

      "reload" ->
        {:ok, %{action: "reload"}}

      "take_screenshot" ->
        {:ok, %{action: "take_screenshot", path: "screenshot_#{:os.system_time(:second)}.png"}}

      "wait" ->
        if is_number(step.params) do
          Process.sleep(step.params)
        end

        {:ok, %{action: "wait", duration: step.params}}

      "pause" ->
        {:ok, %{action: "pause"}}

      "narrate" ->
        {:ok, %{action: "narrate", text: step.params}}

      _ ->
        {:error, "Unknown step type: #{type}"}
    end
  end

  defp broadcast_event(event_type, payload) do
    PubSub.broadcast(
      DanCore.PubSub,
      @pubsub_topic,
      {event_type, payload}
    )
  end

  @doc """
  Returns the PubSub topic for demo events.
  """
  def pubsub_topic, do: @pubsub_topic
end
