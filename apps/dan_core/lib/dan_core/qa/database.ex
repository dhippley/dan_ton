defmodule DanCore.QA.Database do
  @moduledoc """
  SQLite FTS5 database for document search.

  Manages the SQLite connection and provides query interface for full-text search.
  """

  require Logger

  @db_path "apps/dan_core/priv/db/dan_ton.db"

  @doc """
  Initializes the SQLite database and creates FTS5 tables if they don't exist.
  """
  def init do
    with {:ok, conn} <- Exqlite.Sqlite3.open(@db_path),
         :ok <- create_tables(conn),
         :ok <- Exqlite.Sqlite3.close(conn) do
      Logger.info("Q&A database initialized at #{@db_path}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to initialize database: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Executes a query against the database.
  """
  def query(sql, params \\ []) do
    case with_connection(fn conn ->
           execute_query(conn, sql, params)
         end) do
      {:ok, rows} -> {:ok, rows}
      {:error, reason} = error ->
        Logger.error("Database query failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Executes a function with an open database connection.
  """
  def with_connection(fun) do
    case Exqlite.Sqlite3.open(@db_path) do
      {:ok, conn} ->
        result = fun.(conn)
        Exqlite.Sqlite3.close(conn)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Inserts a document into the FTS5 index.
  """
  def index_document(file_path, title, content, section \\ "") do
    with_connection(fn conn ->
      sql = """
      INSERT INTO documents (file_path, title, content, section)
      VALUES (?1, ?2, ?3, ?4)
      """

      case execute_query(conn, sql, [file_path, title, content, section]) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @doc """
  Searches documents using FTS5 full-text search.

  Returns top N results ranked by relevance.
  """
  def search(query_text, limit \\ 10) do
    with_connection(fn conn ->
      sql = """
      SELECT file_path, title, content, section, rank
      FROM documents
      WHERE documents MATCH ?1
      ORDER BY rank
      LIMIT ?2
      """

      case execute_query(conn, sql, [query_text, limit]) do
        {:ok, rows} ->
          results =
            Enum.map(rows, fn [file_path, title, content, section, rank] ->
              %{
                file_path: file_path,
                title: title,
                content: content,
                section: section,
                rank: rank
              }
            end)

          {:ok, results}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc """
  Clears all documents from the index.
  """
  def clear_index do
    with_connection(fn conn ->
      sql = "DELETE FROM documents"

      case execute_query(conn, sql, []) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @doc """
  Counts total indexed documents.
  """
  def count_documents do
    with_connection(fn conn ->
      sql = "SELECT COUNT(*) FROM documents"

      case execute_query(conn, sql, []) do
        {:ok, [[count]]} -> {:ok, count}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Private functions

  defp create_tables(conn) do
    # Create FTS5 virtual table for full-text search
    sql = """
    CREATE VIRTUAL TABLE IF NOT EXISTS documents USING fts5(
      file_path UNINDEXED,
      title,
      content,
      section,
      tokenize = 'porter unicode61'
    )
    """

    case Exqlite.Sqlite3.execute(conn, sql) do
      :ok ->
        Logger.info("FTS5 documents table created")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create tables: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_query(conn, sql, params) do
    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, sql),
         :ok <- bind_params(statement, params),
         {:ok, rows} <- Exqlite.Sqlite3.fetch_all(conn, statement),
         :ok <- Exqlite.Sqlite3.release(conn, statement) do
      {:ok, rows}
    end
  end

  defp bind_params(_statement, []), do: :ok

  defp bind_params(statement, params) do
    # Exqlite.Sqlite3.bind expects a list of values (not tuples)
    case Exqlite.Sqlite3.bind(statement, params) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end
end
