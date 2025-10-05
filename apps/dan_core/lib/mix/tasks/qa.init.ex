defmodule Mix.Tasks.Qa.Init do
  @moduledoc """
  Initializes the Q&A system by creating the database and indexing documents.

  Usage:
      mix qa.init
  """

  use Mix.Task
  require Logger

  @shortdoc "Initialize Q&A system and index documentation"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("Initializing Q&A system...")

    case DanCore.QA.Engine.initialize() do
      {:ok, count} ->
        IO.puts("\n✓ Q&A system initialized successfully!")
        IO.puts("✓ Indexed #{count} document chunks")

        # Show stats
        stats = DanCore.QA.Engine.stats()
        IO.puts("\nSystem Status:")
        IO.puts("  - Documents: #{stats.indexed_documents}")
        IO.puts("  - Ollama: #{if stats.ollama_available, do: "✓ Available", else: "✗ Not available"}")

        if length(stats.available_models) > 0 do
          IO.puts("  - Models: #{Enum.join(stats.available_models, ", ")}")
        else
          IO.puts("\n⚠ Warning: No Ollama models found")
          IO.puts("Run: ollama pull llama3.1:8b")
        end

        IO.puts("\n")

      {:error, reason} ->
        IO.puts("\n✗ Failed to initialize Q&A system")
        IO.puts("Error: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
