defmodule Mix.Tasks.Dan.Demo do
  @moduledoc """
  Run a demo script from the command line.

  Usage:
      mix dan.demo SCRIPT_PATH [options]

  Examples:
      mix dan.demo demo/scripts/example_demo.yml
      mix dan.demo demo/scripts/checkout_demo.yml --headless

  Options:
      --headless    Run without opening browser (just execute steps)
      --step        Execute step-by-step with pauses
      --narrate     Speak each step (requires TTS)
      --list        List available demo scripts

  The demo will execute automatically, showing progress in the terminal.
  """

  use Mix.Task
  require Logger

  @shortdoc "Run a demo script"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:list, _} ->
        list_demos()

      {:run, script, opts} ->
        run_demo(script, opts)

      :error ->
        print_usage()
        exit({:shutdown, 1})
    end
  end

  defp parse_args(["--list" | _]) do
    {:list, []}
  end

  defp parse_args([script | opts]) when is_binary(script) do
    options = parse_options(opts)
    {:run, script, options}
  end

  defp parse_args(_), do: :error

  defp parse_options(opts) do
    opts
    |> Enum.reduce([], fn
      "--headless", acc -> [{:headless, true} | acc]
      "--step", acc -> [{:step, true} | acc]
      "--narrate", acc -> [{:narrate, true} | acc]
      _, acc -> acc
    end)
  end

  defp list_demos do
    IO.puts("\n📋 Available Demo Scripts:\n")

    case File.ls("demo/scripts") do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.sort()
        |> Enum.each(fn file ->
          path = Path.join("demo/scripts", file)
          IO.puts("  • #{path}")

          # Try to read demo name
          case File.read(path) do
            {:ok, content} ->
              case YAML.decode(content) do
                {:ok, %{"name" => name}} ->
                  IO.puts("    #{name}")

                _ ->
                  :ok
              end

            _ ->
              :ok
          end

          IO.puts("")
        end)

      {:error, _} ->
        IO.puts("  No demo scripts found in demo/scripts/")
    end

    IO.puts("Run a demo with: mix dan.demo PATH\n")
  end

  defp run_demo(script, opts) do
    IO.puts("\n🎬 Running Demo: #{script}\n")

    case DanCore.Demo.Runner.start_demo(script) do
      {:ok, name} ->
        IO.puts("✓ Loaded: #{name}")

        if Keyword.get(opts, :narrate) do
          IO.puts("🔊 Narration enabled")
        end

        run_steps(opts)

      {:error, :file_not_found} ->
        IO.puts("❌ Error: Script not found: #{script}")
        IO.puts("\nAvailable scripts:")
        list_demos()
        exit({:shutdown, 1})

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp run_steps(opts) do
    state = DanCore.Demo.Runner.get_state()

    case state.status do
      :idle ->
        IO.puts("\n▶️  Starting demo...\n")
        DanCore.Demo.Runner.start()
        Process.sleep(500)
        run_steps(opts)

      :running ->
        current = state.current_step + 1
        total = length(state.scenario.steps)
        step = Enum.at(state.scenario.steps, state.current_step)

        IO.puts("Step #{current}/#{total}: #{step.type}")

        if step_text = Map.get(step, :text) do
          IO.puts("  → #{step_text}")
        end

        if Keyword.get(opts, :narrate) && step_text do
          DanCore.Speaker.speak(step_text)
        end

        if Keyword.get(opts, :step) do
          IO.gets("  Press Enter for next step...")
        else
          Process.sleep(1000)
        end

        DanCore.Demo.Runner.next_step()
        Process.sleep(500)
        run_steps(opts)

      :completed ->
        IO.puts("\n✅ Demo completed!\n")
        :ok

      :error ->
        IO.puts("\n❌ Demo failed\n")
        exit({:shutdown, 1})

      _ ->
        IO.puts("\n⚠️  Demo in unexpected state: #{state.status}\n")
        exit({:shutdown, 1})
    end
  end

  defp print_usage do
    IO.puts("""
    Usage: mix dan.demo SCRIPT_PATH [options]

    Examples:
      mix dan.demo demo/scripts/example_demo.yml
      mix dan.demo demo/scripts/checkout_demo.yml --step
      mix dan.demo --list

    Options:
      --headless    Run without browser
      --step        Pause between steps
      --narrate     Speak each step (requires TTS)
      --list        List available scripts
    """)
  end
end
