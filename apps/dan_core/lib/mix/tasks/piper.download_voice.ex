defmodule Mix.Tasks.Piper.DownloadVoice do
  @moduledoc """
  Downloads additional Piper voice models.

  Usage:
      mix piper.download_voice VOICE_NAME

  Examples:
      mix piper.download_voice en_GB-alan-medium
      mix piper.download_voice en_US-amy-medium
      mix piper.download_voice de_DE-thorsten-medium

  See available voices at:
  https://github.com/rhasspy/piper/blob/master/VOICES.md
  """

  use Mix.Task
  require Logger

  @shortdoc "Download a Piper voice model"

  @impl Mix.Task
  def run([voice]) do
    Mix.Task.run("app.start")

    IO.puts("\n🎙️  Downloading voice: #{voice}\n")

    case DanCore.TTS.Piper.download_voice_model(voice) do
      :ok ->
        IO.puts("\n✅ Voice downloaded: #{voice}")
        IO.puts("\nUse it with:")
        IO.puts("  DanCore.TTS.speak(\"Hello\", voice: \"#{voice}\")")
        IO.puts("")

      {:error, reason} ->
        IO.puts("\n❌ Download failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  def run(_) do
    IO.puts("Usage: mix piper.download_voice VOICE_NAME")
    IO.puts("\nExamples:")
    IO.puts("  mix piper.download_voice en_GB-alan-medium")
    IO.puts("  mix piper.download_voice en_US-amy-medium")
    IO.puts("\nSee: https://github.com/rhasspy/piper/blob/master/VOICES.md")
    exit({:shutdown, 1})
  end
end
