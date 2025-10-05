defmodule Mix.Tasks.Piper.Setup do
  @moduledoc """
  Downloads and sets up Piper TTS with voice models.

  Usage:
      mix piper.setup

  This will:
  - Download the Piper binary for your platform
  - Download the default English voice model (en_US-lessac-medium)
  - Make the binary executable
  - Verify the installation

  Additional voices can be downloaded with:
      mix piper.download_voice en_GB-alan-medium
  """

  use Mix.Task
  require Logger

  @shortdoc "Setup Piper TTS system"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("\n🎙️  Setting up Piper TTS...\n")

    case DanCore.TTS.Piper.setup() do
      :ok ->
        IO.puts("\n✅ Piper TTS setup complete!")
        IO.puts("\nTest it with:")
        IO.puts("  iex -S mix")
        IO.puts("  DanCore.TTS.Piper.speak(\"Hello, I am Piper!\")")
        IO.puts("")

      {:error, reason} ->
        IO.puts("\n❌ Setup failed: #{inspect(reason)}")
        IO.puts("\nTroubleshooting:")
        IO.puts("  - Check your internet connection")
        IO.puts("  - Verify platform compatibility")
        IO.puts("  - Check file permissions")
        exit({:shutdown, 1})
    end
  end
end
