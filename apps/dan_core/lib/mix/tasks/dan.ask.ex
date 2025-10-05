defmodule Mix.Tasks.Dan.Ask do
  @moduledoc """
  Ask a question to the AI assistant from the command line.

  Usage:
      mix dan.ask "QUESTION" [options]

  Examples:
      mix dan.ask "How does the demo system work?"
      mix dan.ask "What is RAG?" --speak
      mix dan.ask "Explain Q&A" --citations

  Options:
      --speak       Speak the answer using TTS
      --no-citations  Hide source citations
      --model MODEL Use specific Ollama model

  The assistant uses RAG to search documentation and generate accurate answers.
  """

  use Mix.Task
  require Logger

  @shortdoc "Ask a question to the AI assistant"

  @impl Mix.Task
  def run([]) do
    print_usage()
    exit({:shutdown, 1})
  end

  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {question, opts} ->
        ask_question(question, opts)

      :error ->
        print_usage()
        exit({:shutdown, 1})
    end
  end

  defp parse_args(args) do
    case extract_question(args) do
      {nil, _} -> :error
      {question, remaining} -> {question, parse_options(remaining)}
    end
  end

  defp extract_question([first | rest]) do
    if String.starts_with?(first, "--") do
      {nil, []}
    else
      {first, rest}
    end
  end

  defp extract_question(_), do: {nil, []}

  defp parse_options(opts) do
    Enum.reduce(opts, [], fn
      "--speak", acc -> [{:speak, true} | acc]
      "--no-citations", acc -> [{:citations, false} | acc]
      "--model", acc -> acc
      model, [{:model, _} | acc] -> [{:model, model} | acc]
      _, acc -> acc
    end)
  end

  defp ask_question(question, opts) do
    IO.puts("\n🤔 Question: #{question}\n")
    IO.puts("Thinking...\n")

    # Check if Ollama is available
    unless DanCore.QA.Ollama.available?() do
      IO.puts("⚠️  Warning: Ollama is not running")
      IO.puts("Start Ollama with: ollama serve")
      IO.puts("Pull a model with: ollama pull llama3.1:8b\n")
    end

    rag_opts =
      if model = Keyword.get(opts, :model) do
        [model: model]
      else
        []
      end

    case DanCore.QA.Engine.ask(question, rag_opts) do
      {:ok, response} ->
        IO.puts("💡 Answer:\n")
        IO.puts(wrap_text(response.answer, 80))
        IO.puts("")

        if Keyword.get(opts, :citations, true) && Map.get(response, :citations) &&
             length(response.citations) > 0 do
          IO.puts("📚 Sources:")

          Enum.each(response.citations, fn citation ->
            IO.puts("  • #{citation}")
          end)

          IO.puts("")
        end

        if Keyword.get(opts, :speak) do
          IO.puts("🔊 Speaking answer...")
          DanCore.Speaker.speak(response.answer)
          # Wait for speech to complete
          Process.sleep(1000)

          wait_for_speech()
        end

        :ok

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}\n")

        case reason do
          :ollama_unavailable ->
            IO.puts("Ollama is not running. Start it with: ollama serve")

          :no_documents ->
            IO.puts("No documents indexed. Run: mix qa.init")

          _ ->
            :ok
        end

        exit({:shutdown, 1})
    end
  end

  defp wait_for_speech do
    if DanCore.Speaker.speaking?() do
      Process.sleep(500)
      wait_for_speech()
    else
      IO.puts("✓ Done\n")
    end
  end

  defp wrap_text(text, width) do
    text
    |> String.split("\n")
    |> Enum.map(&wrap_line(&1, width))
    |> Enum.join("\n")
  end

  defp wrap_line(line, width) do
    line
    |> String.split(" ")
    |> Enum.reduce({[], 0}, fn word, {lines, current_length} ->
      word_length = String.length(word)

      cond do
        current_length == 0 ->
          {[word], word_length}

        current_length + word_length + 1 <= width ->
          [current_line | rest] = lines
          {["#{current_line} #{word}" | rest], current_length + word_length + 1}

        true ->
          {[word | lines], word_length}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp print_usage do
    IO.puts("""
    Usage: mix dan.ask "QUESTION" [options]

    Examples:
      mix dan.ask "How does the demo system work?"
      mix dan.ask "What is RAG?" --speak
      mix dan.ask "Explain LiveView" --model llama2:7b

    Options:
      --speak         Speak the answer using TTS
      --no-citations  Hide source citations
      --model MODEL   Use specific Ollama model
    """)
  end
end
