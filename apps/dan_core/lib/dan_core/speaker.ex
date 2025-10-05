defmodule DanCore.Speaker do
  @moduledoc """
  GenServer for managing TTS speech queue and playback.

  Prevents overlapping speech by queueing requests and playing them sequentially.
  Broadcasts state changes via PubSub for UI updates.
  """

  use GenServer
  require Logger
  alias Phoenix.PubSub

  defmodule State do
    @moduledoc false
    defstruct queue: :queue.new(),
              speaking: false,
              current_text: nil,
              voice: nil
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queues text to be spoken.

  Options:
  - `:voice` - Voice to use (defaults to adapter default)
  - `:priority` - :high or :normal (default: :normal)
  """
  def speak(text, opts \\ []) do
    GenServer.cast(__MODULE__, {:speak, text, opts})
  end

  @doc """
  Stops current speech and clears the queue.
  """
  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  @doc """
  Clears the speech queue without stopping current speech.
  """
  def clear_queue do
    GenServer.cast(__MODULE__, :clear_queue)
  end

  @doc """
  Returns true if currently speaking.
  """
  def speaking? do
    GenServer.call(__MODULE__, :speaking?)
  end

  @doc """
  Returns the current state of the speaker.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Returns the PubSub topic for speaker events.
  """
  def pubsub_topic, do: "speaker:events"

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Speaker GenServer started")
    {:ok, %State{}}
  end

  @impl true
  def handle_cast({:speak, text, opts}, state) do
    priority = Keyword.get(opts, :priority, :normal)

    new_queue =
      case priority do
        :high -> :queue.in_r({text, opts}, state.queue)
        _ -> :queue.in({text, opts}, state.queue)
      end

    state = %{state | queue: new_queue}

    # Start processing if not already speaking
    if not state.speaking do
      send(self(), :process_queue)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:clear_queue, state) do
    Logger.info("Clearing speech queue")
    broadcast({:queue_cleared, %{}})
    {:noreply, %{state | queue: :queue.new()}}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    Logger.info("Stopping speech")
    DanCore.TTS.stop()

    state = %{
      state
      | speaking: false,
        current_text: nil,
        queue: :queue.new()
    }

    broadcast({:stopped, %{}})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:speaking?, _from, state) do
    {:reply, state.speaking, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    response = %{
      speaking: state.speaking,
      current_text: state.current_text,
      queue_size: :queue.len(state.queue)
    }

    {:reply, response, state}
  end

  @impl true
  def handle_info(:process_queue, state) do
    case :queue.out(state.queue) do
      {{:value, {text, opts}}, new_queue} ->
        Logger.info("Speaking: #{String.slice(text, 0..50)}...")

        state = %{
          state
          | queue: new_queue,
            speaking: true,
            current_text: text,
            voice: Keyword.get(opts, :voice)
        }

        broadcast({:started, %{text: text}})

        # Speak in async task
        task =
          Task.async(fn ->
            DanCore.TTS.speak(text, opts)
          end)

        {:noreply, Map.put(state, :current_task, task)}

      {:empty, _} ->
        {:noreply, %{state | speaking: false, current_text: nil}}
    end
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    # Task completed
    Process.demonitor(ref, [:flush])

    case result do
      :ok ->
        Logger.debug("Speech completed successfully")
        broadcast({:completed, %{text: state.current_text}})

      {:error, reason} ->
        Logger.error("Speech failed: #{inspect(reason)}")
        broadcast({:error, %{reason: reason}})
    end

    # Process next item in queue
    send(self(), :process_queue)

    state = %{
      state
      | speaking: false,
        current_text: nil
    }
    |> Map.delete(:current_task)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task crashed
    Logger.warning("Speech task crashed")
    broadcast({:error, %{reason: :task_crashed}})

    send(self(), :process_queue)

    state = %{
      state
      | speaking: false,
        current_text: nil
    }
    |> Map.delete(:current_task)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp broadcast(event) do
    PubSub.broadcast(DanCore.PubSub, pubsub_topic(), event)
  end
end
