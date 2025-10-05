defmodule DanCore.QA.Indexer do
  @moduledoc """
  Indexes markdown documentation files into the FTS5 search database.
  
  Scans demo/docs/ recursively, parses markdown files, and indexes their content
  for full-text search and RAG retrieval.
  """

  require Logger
  alias DanCore.QA.Database

  @docs_path "demo/docs"

  @doc """
  Indexes all documentation files from demo/docs/
  
  Returns {:ok, count} where count is the number of files indexed.
  """
  def index_all do
    Logger.info("Starting full document indexing...")

    with :ok <- Database.clear_index() do
      case find_markdown_files() do
        {:ok, files} ->
          Logger.info("Found #{length(files)} markdown files")
          count = index_files(files)
          Logger.info("Indexed #{count} document chunks")
          {:ok, count}

        {:error, reason} = error ->
          Logger.error("Failed to find markdown files: #{inspect(reason)}")
          error
      end
    else
      {:error, reason} = error ->
        Logger.error("Failed to clear index: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Indexes a single markdown file.
  """
  def index_file(file_path) do
    Logger.debug("Indexing file: #{file_path}")

    with {:ok, content} <- File.read(file_path),
         {:ok, chunks} <- parse_markdown(content, file_path),
         :ok <- index_chunks(chunks, file_path) do
      Logger.debug("Successfully indexed: #{file_path}")
      :ok
    else
      {:error, reason} = error ->
        Logger.warning("Failed to index #{file_path}: #{inspect(reason)}")
        error
    end
  end

  # Private functions

  defp find_markdown_files do
    docs_path = Path.join([File.cwd!(), @docs_path])

    case File.ls(docs_path) do
      {:ok, _} ->
        files =
          Path.wildcard(Path.join([docs_path, "**", "*.md"]))
          |> Enum.filter(&File.regular?/1)

        {:ok, files}

      {:error, :enoent} ->
        Logger.warning("Documentation directory not found: #{docs_path}")
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp index_files(files) do
    files
    |> Enum.reduce(0, fn file, count ->
      case index_file(file) do
        :ok ->
          count + 1

        {:error, reason} ->
          Logger.warning("Skipping file #{file}: #{inspect(reason)}")
          count
      end
    end)
  end

  defp parse_markdown(content, file_path) do
    # Convert markdown to HTML AST to extract structure
    case Earmark.as_ast(content) do
      {:ok, ast, _} ->
        chunks = extract_chunks(ast, file_path)
        {:ok, chunks}

      {:error, _, errors} ->
        Logger.warning("Failed to parse markdown: #{inspect(errors)}")
        # Fall back to simple chunking
        chunks = simple_chunk(content, file_path)
        {:ok, chunks}
    end
  end

  defp extract_chunks(ast, file_path) do
    title = extract_title(ast) || Path.basename(file_path, ".md")

    ast
    |> flatten_ast()
    |> Enum.chunk_by(&heading?/1)
    |> Enum.reduce({[], nil}, fn group, {chunks, current_section} ->
      case group do
        # Heading starts a new section
        [{:h1, _, [heading_text], _} | rest] ->
          section_content = extract_text(rest)

          chunk = %{
            title: title,
            section: heading_text,
            content: section_content
          }

          {[chunk | chunks], heading_text}

        [{:h2, _, [heading_text], _} | rest] ->
          section_content = extract_text(rest)

          chunk = %{
            title: title,
            section: heading_text,
            content: section_content
          }

          {[chunk | chunks], heading_text}

        [{:h3, _, [heading_text], _} | rest] ->
          section_content = extract_text(rest)

          chunk = %{
            title: title,
            section: heading_text,
            content: section_content
          }

          {[chunk | chunks], heading_text}

        # Regular content
        content_nodes ->
          content = extract_text(content_nodes)

          if String.trim(content) != "" do
            chunk = %{
              title: title,
              section: current_section || "",
              content: content
            }

            {[chunk | chunks], current_section}
          else
            {chunks, current_section}
          end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp flatten_ast(ast) do
    Enum.flat_map(ast, fn node ->
      case node do
        {tag, attrs, children, meta} when is_list(children) ->
          [{tag, attrs, extract_text_from_children(children), meta}]

        other ->
          [other]
      end
    end)
  end

  defp extract_text_from_children(children) when is_list(children) do
    children
    |> Enum.map(fn
      {_, _, nested, _} when is_list(nested) -> extract_text_from_children(nested)
      text when is_binary(text) -> text
      _ -> ""
    end)
    |> Enum.join(" ")
  end

  defp extract_text_from_children(text) when is_binary(text), do: text
  defp extract_text_from_children(_), do: ""

  defp heading?({tag, _, _, _}) when tag in [:h1, :h2, :h3, :h4, :h5, :h6], do: true
  defp heading?(_), do: false

  defp extract_title(ast) do
    Enum.find_value(ast, fn
      {:h1, _, [title], _} -> title
      _ -> nil
    end)
  end

  defp extract_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(fn
      {_, _, content, _} when is_binary(content) -> content
      {_, _, content, _} when is_list(content) -> extract_text_from_children(content)
      text when is_binary(text) -> text
      _ -> ""
    end)
    |> Enum.join("\n")
    |> String.trim()
  end

  # Fallback: simple paragraph-based chunking
  defp simple_chunk(content, file_path) do
    title = Path.basename(file_path, ".md")

    content
    |> String.split("\n\n")
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.map(fn chunk ->
      %{
        title: title,
        section: "",
        content: String.trim(chunk)
      }
    end)
  end

  defp index_chunks(chunks, file_path) do
    # Make file_path relative to project root for cleaner citations
    relative_path = Path.relative_to(file_path, File.cwd!())

    results =
      Enum.map(chunks, fn chunk ->
        Database.index_document(
          relative_path,
          chunk.title,
          chunk.content,
          chunk.section
        )
      end)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :partial_indexing_failure}
    end
  end
end
