defmodule DanCore.Demo.PlaywrightPort do
  @moduledoc """
  Port wrapper for communicating with the Node.js Playwright bridge.

  Manages the lifecycle of the Node.js process and handles JSON
  communication over stdio.
  """

  use GenServer
  require Logger

  @bridge_script Path.join([
                   :code.priv_dir(:dan_core),
                   "node_bridge",
                   "bridge.js"
                 ])

  defmodule State do
    @moduledoc false
    defstruct [:port, :caller, pending_responses: %{}]
  end

  # Client API

  @doc """
  Starts the Playwright bridge process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a command on the Playwright bridge.

  ## Examples

      iex> PlaywrightPort.execute(%{action: "goto", params: "https://example.com"})
      {:ok, %{"status" => "ok", "url" => "https://example.com"}}
  """
  @spec execute(map()) :: {:ok, map()} | {:error, term()}
  def execute(command) do
    GenServer.call(__MODULE__, {:execute, command}, 30_000)
  end

  @doc """
  Initializes the browser.
  """
  def init_browser do
    execute(%{action: "init"})
  end

  @doc """
  Closes the browser and terminates the bridge.
  """
  def close do
    GenServer.call(__MODULE__, :close)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Start the Node.js bridge process
    port =
      Port.open(
        {:spawn_executable, System.find_executable("node")},
        [
          :binary,
          :exit_status,
          {:args, [@bridge_script]},
          {:line, 10_000},
          {:cd, Path.dirname(@bridge_script)}
        ]
      )

    state = %State{port: port}

    Logger.info("Playwright bridge started")

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, command}, from, state) do
    # Send command to bridge
    command_json = Jason.encode!(command)
    Port.command(state.port, command_json <> "\n")

    # Store caller to respond later
    request_id = make_ref()

    new_state = %{
      state
      | caller: from,
        pending_responses: Map.put(state.pending_responses, request_id, from)
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:close, _from, state) do
    if state.port do
      Port.command(state.port, Jason.encode!(%{action: "close"}) <> "\n")
      Process.sleep(500)
      Port.close(state.port)
    end

    {:reply, :ok, %{state | port: nil}}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %State{port: port} = state) do
    # Received a line from the bridge
    case Jason.decode(line) do
      {:ok, response} ->
        handle_bridge_response(response, state)

      {:error, reason} ->
        Logger.error("Failed to parse bridge response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %State{port: port} = state) do
    Logger.warning("Playwright bridge exited with status: #{status}")
    {:stop, {:bridge_exit, status}, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Playwright bridge terminating: #{inspect(reason)}")

    if state.port do
      Port.close(state.port)
    end

    :ok
  end

  # Private Functions

  defp handle_bridge_response(%{"status" => "ready"} = response, state) do
    Logger.info("Bridge ready: #{response["message"]}")
    {:noreply, state}
  end

  defp handle_bridge_response(%{"status" => "ok"} = response, state) do
    if state.caller do
      GenServer.reply(state.caller, {:ok, response})
      {:noreply, %{state | caller: nil}}
    else
      Logger.debug("Received response with no caller: #{inspect(response)}")
      {:noreply, state}
    end
  end

  defp handle_bridge_response(%{"status" => "error"} = response, state) do
    error = %{
      message: response["message"],
      details: response["error"]
    }

    if state.caller do
      GenServer.reply(state.caller, {:error, error})
      {:noreply, %{state | caller: nil}}
    else
      Logger.error("Received error with no caller: #{inspect(error)}")
      {:noreply, state}
    end
  end

  defp handle_bridge_response(response, state) do
    Logger.warning("Unexpected bridge response: #{inspect(response)}")
    {:noreply, state}
  end
end
