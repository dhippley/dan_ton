defmodule DanWeb.DemoLive do
  @moduledoc """
  LiveView for real-time demo control and monitoring.

  Provides:
  - Demo script selection and loading
  - Real-time step execution display
  - Progress tracking
  - Status logs
  - Keyboard shortcuts for hands-free operation
  """

  use DanWeb, :live_view
  require Logger

  alias DanCore.Demo.Runner
  alias DanCore.QA.Engine
  alias DanCore.Speaker
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to demo events
      PubSub.subscribe(DanCore.PubSub, Runner.pubsub_topic())
      # Subscribe to speaker events
      PubSub.subscribe(DanCore.PubSub, Speaker.pubsub_topic())
    end

    # Get available demo scripts
    demo_scripts = list_demo_scripts()

    # Get current demo state
    demo_state = Runner.get_state()

    # Get speaker state
    speaker_state = Speaker.get_state()

    socket =
      socket
      |> assign(:demo_scripts, demo_scripts)
      |> assign(:selected_script, nil)
      |> assign(:demo_state, demo_state)
      |> assign(:logs, [])
      |> assign(:show_help, false)
      |> assign(:show_qa, false)
      |> assign(:qa_question, "")
      |> assign(:qa_answer, nil)
      |> assign(:qa_loading, false)
      |> assign(:speaker_state, speaker_state)
      |> assign(:tts_available, DanCore.TTS.available?())

    {:ok, socket}
  end

  @impl true
  def handle_event("load_demo", %{"script" => script_path}, socket) do
    case Runner.start_demo(script_path) do
      {:ok, name} ->
        add_log(socket, "info", "Demo loaded: #{name}")

      {:error, reason} ->
        add_log(socket, "error", "Failed to load demo: #{reason}")
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    case Runner.next_step() do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, add_log(socket, "error", "Step failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("previous_step", _params, socket) do
    case Runner.previous_step() do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, add_log(socket, "error", "Cannot go back: #{reason}")}
    end
  end

  @impl true
  def handle_event("restart_demo", _params, socket) do
    case Runner.restart() do
      :ok ->
        {:noreply, add_log(socket, "info", "Demo restarted")}

      {:error, reason} ->
        {:noreply, add_log(socket, "error", "Restart failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("recover", _params, socket) do
    case Runner.recover() do
      :ok ->
        {:noreply, add_log(socket, "info", "Recovery completed")}

      {:error, reason} ->
        {:noreply, add_log(socket, "error", "Recovery failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("stop_demo", _params, socket) do
    :ok = Runner.stop_demo()
    {:noreply, add_log(socket, "info", "Demo stopped")}
  end

  @impl true
  def handle_event("toggle_help", _params, socket) do
    {:noreply, assign(socket, :show_help, !socket.assigns.show_help)}
  end

  @impl true
  def handle_event("select_script", %{"path" => path}, socket) do
    {:noreply, assign(socket, :selected_script, path)}
  end

  @impl true
  def handle_event("toggle_qa", _params, socket) do
    {:noreply, assign(socket, :show_qa, !socket.assigns.show_qa)}
  end

  @impl true
  def handle_event("ask_question", %{"question" => question}, socket) do
    if String.trim(question) == "" do
      {:noreply, socket}
    else
      # Start async task to query the Q&A engine
      socket =
        socket
        |> assign(:qa_loading, true)
        |> assign(:qa_question, question)

      Task.async(fn -> Engine.ask(question) end)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_qa", _params, socket) do
    socket =
      socket
      |> assign(:qa_question, "")
      |> assign(:qa_answer, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("speak_answer", _params, socket) do
    if socket.assigns.qa_answer do
      Speaker.speak(socket.assigns.qa_answer.answer)
      {:noreply, add_log(socket, "info", "Speaking answer...")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_speaking", _params, socket) do
    Speaker.stop()
    {:noreply, add_log(socket, "info", "Speech stopped")}
  end

  # PubSub event handlers

  @impl true
  def handle_info({:demo_started, payload}, socket) do
    socket =
      socket
      |> update_demo_state()
      |> add_log("success", "Demo started: #{payload.name} (#{payload.total_steps} steps)")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:step_executed, payload}, socket) do
    step_type = payload.step.type
    progress = "#{payload.step_index + 1}/#{payload.total_steps}"

    socket =
      socket
      |> update_demo_state()
      |> add_log("info", "Step #{progress}: #{step_type}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:step_failed, payload}, socket) do
    socket =
      socket
      |> update_demo_state()
      |> add_log("error", "Step failed: #{payload.error}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:demo_completed, payload}, socket) do
    socket =
      socket
      |> update_demo_state()
      |> add_log("success", "Demo completed: #{payload.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:demo_stopped, _payload}, socket) do
    socket =
      socket
      |> update_demo_state()
      |> add_log("info", "Demo stopped")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:demo_restarted, payload}, socket) do
    socket =
      socket
      |> update_demo_state()
      |> add_log("info", "Demo restarted: #{payload.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:recovery_completed, payload}, socket) do
    socket =
      socket
      |> update_demo_state()
      |> add_log("success", "Recovery completed (#{payload.steps} steps)")

    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, result}, socket) when is_reference(ref) do
    # Handle async task result (Q&A response)
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, response} ->
        socket =
          socket
          |> assign(:qa_loading, false)
          |> assign(:qa_answer, response)
          |> add_log("success", "Q&A: Answered question")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:qa_loading, false)
          |> add_log("error", "Q&A failed: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task cleanup
    {:noreply, socket}
  end

  # Speaker event handlers

  @impl true
  def handle_info({:started, payload}, socket) do
    speaker_state = Speaker.get_state()

    socket =
      socket
      |> assign(:speaker_state, speaker_state)
      |> add_log("info", "Speaking: #{String.slice(payload.text, 0..50)}...")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:completed, _payload}, socket) do
    speaker_state = Speaker.get_state()

    socket =
      socket
      |> assign(:speaker_state, speaker_state)
      |> add_log("success", "Speech completed")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stopped, _payload}, socket) do
    speaker_state = Speaker.get_state()
    {:noreply, assign(socket, :speaker_state, speaker_state)}
  end

  @impl true
  def handle_info({:queue_cleared, _payload}, socket) do
    speaker_state = Speaker.get_state()
    {:noreply, assign(socket, :speaker_state, speaker_state)}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  # Private functions

  defp update_demo_state(socket) do
    demo_state = Runner.get_state()
    assign(socket, :demo_state, demo_state)
  end

  defp add_log(socket, level, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    log_entry = %{timestamp: timestamp, level: level, message: message}

    logs =
      [log_entry | socket.assigns.logs]
      |> Enum.take(100)

    assign(socket, :logs, logs)
  end

  defp list_demo_scripts do
    scripts_path = Path.join([File.cwd!(), "demo", "scripts"])

    case File.ls(scripts_path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.map(fn file ->
          path = Path.join(["demo", "scripts", file])
          %{name: file, path: path}
        end)

      {:error, _} ->
        []
    end
  end

  defp log_color("info"), do: "text-blue-400"
  defp log_color("success"), do: "text-green-400"
  defp log_color("error"), do: "text-red-400"
  defp log_color("warning"), do: "text-yellow-400"
  defp log_color(_), do: "text-gray-400"

  defp status_badge_color(:idle), do: "badge-ghost"
  defp status_badge_color(:running), do: "badge-primary"
  defp status_badge_color(:paused), do: "badge-warning"
  defp status_badge_color(:completed), do: "badge-success"
  defp status_badge_color(:error), do: "badge-error"
  defp status_badge_color(_), do: "badge-ghost"

  defp status_text(:idle), do: "IDLE"
  defp status_text(:running), do: "RUNNING"
  defp status_text(:paused), do: "PAUSED"
  defp status_text(:completed), do: "COMPLETED"
  defp status_text(:error), do: "ERROR"
  defp status_text(_), do: "UNKNOWN"
end
