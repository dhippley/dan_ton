defmodule DanCore.QA.Engine do
  @moduledoc """
  RAG (Retrieval-Augmented Generation) query engine.

  Combines full-text search with LLM generation to answer questions about documentation.

  Pipeline:
  1. Query → FTS5 search (retrieve top N chunks)
  2. Build context from retrieved documents
  3. Create prompt with context + question
  4. Call Ollama for generation
  5. Format response with citations
  """

  require Logger
  alias DanCore.QA.{Database, Ollama, Indexer}

  @default_retrieve_count 5
  @max_context_length 2000

  @doc """
  Answers a question using RAG pipeline.

  Options:
  - `:retrieve_count` - Number of documents to retrieve (default: 5)
  - `:model` - Ollama model to use (default: "llama3.1:8b")
  - `:include_citations` - Include source citations (default: true)
  """
  def ask(question, opts \\ []) do
    retrieve_count = Keyword.get(opts, :retrieve_count, @default_retrieve_count)
    include_citations = Keyword.get(opts, :include_citations, true)

    Logger.info("Processing question: #{String.slice(question, 0..50)}...")

    with {:ok, docs} <- retrieve_documents(question, retrieve_count),
         context <- build_context(docs),
         {:ok, answer} <- generate_answer(question, context, opts),
         response <- format_response(answer, docs, include_citations) do
      {:ok, response}
    else
      {:error, reason} = error ->
        Logger.error("Failed to answer question: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Initializes the Q&A system by setting up the database and indexing documents.
  """
  def initialize do
    Logger.info("Initializing Q&A system...")

    with :ok <- Database.init(),
         {:ok, count} <- Indexer.index_all() do
      Logger.info("Q&A system initialized with #{count} documents")
      {:ok, count}
    else
      {:error, reason} = error ->
        Logger.error("Failed to initialize Q&A system: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Re-indexes all documentation.
  """
  def reindex do
    Indexer.index_all()
  end

  @doc """
  Returns statistics about the indexed documents.
  """
  def stats do
    with {:ok, doc_count} <- Database.count_documents(),
         available <- Ollama.available?(),
         {:ok, models} <- Ollama.list_models() do
      %{
        indexed_documents: doc_count,
        ollama_available: available,
        available_models: models
      }
    else
      {:error, _} ->
        %{
          indexed_documents: 0,
          ollama_available: false,
          available_models: []
        }
    end
  end

  @doc """
  Tests the Q&A system with a sample question.
  """
  def test do
    question = "How does the demo system work?"

    case ask(question) do
      {:ok, response} ->
        IO.puts("\n=== Q&A System Test ===")
        IO.puts("Question: #{question}")
        IO.puts("\nAnswer:")
        IO.puts(response.answer)

        if response.citations != [] do
          IO.puts("\nSources:")

          Enum.each(response.citations, fn citation ->
            IO.puts("  - #{citation}")
          end)
        end

        IO.puts("\n=== Test Complete ===\n")
        :ok

      {:error, reason} ->
        IO.puts("Test failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp retrieve_documents(question, limit) do
    Logger.debug("Retrieving documents for query...")

    case Database.search(question, limit) do
      {:ok, []} ->
        Logger.warning("No documents found for query")
        {:ok, []}

      {:ok, docs} ->
        Logger.debug("Retrieved #{length(docs)} documents")
        {:ok, docs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_context(docs) when docs == [] do
    ""
  end

  defp build_context(docs) do
    context =
      docs
      |> Enum.map(fn doc ->
        section_prefix = if doc.section != "", do: "[#{doc.section}]\n", else: ""
        "#{section_prefix}#{doc.content}"
      end)
      |> Enum.join("\n\n---\n\n")
      |> String.slice(0, @max_context_length)

    Logger.debug("Built context (#{String.length(context)} chars)")
    context
  end

  defp generate_answer(_question, "", opts) do
    # No context found, still try to answer
    Logger.warning("Generating answer without context")
    model = Keyword.get(opts, :model)
    question = "I don't have specific documentation to reference. Can you help anyway?"

    Ollama.generate(question, "", model: model)
  end

  defp generate_answer(question, context, opts) do
    model = Keyword.get(opts, :model)
    Ollama.generate(question, context, model: model)
  end

  defp format_response(answer, docs, true = _include_citations) do
    citations =
      docs
      |> Enum.map(fn doc ->
        if doc.section != "" do
          "#{doc.file_path}##{format_section(doc.section)}"
        else
          doc.file_path
        end
      end)
      |> Enum.uniq()

    %{
      answer: answer,
      citations: citations,
      source_count: length(docs)
    }
  end

  defp format_response(answer, docs, false = _include_citations) do
    %{
      answer: answer,
      source_count: length(docs)
    }
  end

  defp format_section(section) do
    section
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
  end
end
