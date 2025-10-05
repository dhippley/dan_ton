defmodule Mix.Tasks.Dan.Speak do
  @moduledoc """
  Test text-to-speech from the command line.

  Usage:
      mix dan.speak "TEXT" [options]
      mix dan.speak --list
      mix dan.speak --test

  Examples:
      mix dan.speak "Hello, world!"
      mix dan.speak "Testing voices" --voice en_GB-alan-medium
      mix dan.speak --list
      mix dan.speak --test

  Options:
      --list            List available voices
      --test            Run a TTS test
      --voice VOICE     Use specific voice
      --adapter ADAPTER Use specific TTS adapter (Piper, MacSay, Null)

  This is useful for testing your TTS setup and trying different voices.
  """

  use Mix.Task
  require Logger

  @shortdoc "Test text-to-speech"

  @impl Mix.Task
  def run([]) do
    print_usage()
  end

  def run(["--list" | _]) do
    Mix.Task.run("app.start")
    list_voices()
  end

  def run(["--test" | _]) do
    Mix.Task.run("app.start")
    run_test()
  end

  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {text, opts} ->
        speak_text(text, opts)

      :error ->
        print_usage()
        exit({:shutdown, 1})
    end
  end

  defp parse_args([text | opts]) do
    if String.starts_with?(text, "--") do
      :error
    else
      {text, parse_options(opts)}
    end
  end

  defp parse_args(_), do: :error

  defp parse_options(opts) do
    parse_options(opts, [])
  end

  defp parse_options([], acc), do: Enum.reverse(acc)

  defp parse_options(["--voice", voice | rest], acc) do
    parse_options(rest, [{:voice, voice} | acc])
  end

  defp parse_options(["--adapter", adapter | rest], acc) do
    adapter_module =
      case String.downcase(adapter) do
        "piper" -> DanCore.TTS.Piper
        "macsay" -> DanCore.TTS.MacSay
        "null" -> DanCore.TTS.Null
        _ -> nil
      end

    if adapter_module do
      parse_options(rest, [{:adapter, adapter_module} | acc])
    else
      IO.puts("⚠️  Unknown adapter: #{adapter}")
      parse_options(rest, acc)
    end
  end

  defp parse_options([_ | rest], acc), do: parse_options(rest, acc)

  defp list_voices do
    IO.puts("\n🎙️  Available TTS System:\n")

    adapter = DanCore.TTS.adapter()
    IO.puts("Current Adapter: #{inspect(adapter)}")
    IO.puts("Available: #{if DanCore.TTS.available?(), do: "✓", else: "✗"}")
    IO.puts("")

    case DanCore.TTS.voice_list() do
      {:ok, [_ | _] = voices} ->
        IO.puts("Available Voices:")

        Enum.each(voices, fn voice ->
          default_marker =
            if voice == DanCore.TTS.default_voice(), do: " (default)", else: ""

          IO.puts("  • #{voice}#{default_marker}")
        end)

        IO.puts("\nUse a voice with: mix dan.speak \"Text\" --voice VOICE_NAME\n")

      {:ok, []} ->
        IO.puts("No voices available.\n")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}\n")
    end

    # List all adapters
    IO.puts("\nAll Adapters:")
    IO.puts("  • Piper: #{if DanCore.TTS.Piper.available?(), do: "✓", else: "✗"}")
    IO.puts("  • MacSay: #{if DanCore.TTS.MacSay.available?(), do: "✓", else: "✗"}")
    IO.puts("")
  end

  defp run_test do
    IO.puts("\n🧪 Running TTS Test...\n")

    test_text = "Hello! I am the dan ton demo assistant. I can speak different sentences."

    adapter = DanCore.TTS.adapter()
    IO.puts("Using adapter: #{inspect(adapter)}")

    if DanCore.TTS.available?() do
      IO.puts("✓ TTS is available")
      IO.puts("\nSpeaking: \"#{test_text}\"\n")

      case DanCore.TTS.speak(test_text) do
        :ok ->
          IO.puts("✓ Speech completed successfully!\n")

        {:error, reason} ->
          IO.puts("❌ Speech failed: #{inspect(reason)}\n")
      end
    else
      IO.puts("❌ TTS is not available")
      IO.puts("\nSetup instructions:")
      IO.puts("  1. For Piper: run 'mix piper.setup'")
      IO.puts("  2. For MacSay: available on macOS by default")
      IO.puts("")
    end
  end

  defp speak_text(text, opts) do
    adapter = Keyword.get(opts, :adapter, DanCore.TTS.adapter())

    IO.puts("\n🔊 Speaking...\n")
    IO.puts("Text: #{text}")
    IO.puts("Adapter: #{inspect(adapter)}")

    if voice = Keyword.get(opts, :voice) do
      IO.puts("Voice: #{voice}")
    end

    IO.puts("")

    speech_opts = Keyword.take(opts, [:voice])

    case DanCore.TTS.speak(text, speech_opts) do
      :ok ->
        IO.puts("✓ Done!\n")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}\n")

        case reason do
          :binary_not_found ->
            IO.puts("Piper binary not found. Run: mix piper.setup")

          :model_not_found ->
            IO.puts("Voice model not found. Run: mix piper.download_voice VOICE")

          _ ->
            :ok
        end

        exit({:shutdown, 1})
    end
  end

  defp print_usage do
    IO.puts("""
    Usage: mix dan.speak "TEXT" [options]

    Examples:
      mix dan.speak "Hello, world!"
      mix dan.speak "Testing" --voice en_GB-alan-medium
      mix dan.speak --list
      mix dan.speak --test

    Options:
      --list            List available voices
      --test            Run TTS test
      --voice VOICE     Use specific voice
      --adapter ADAPTER Force specific adapter (Piper, MacSay)
    """)
  end
end
