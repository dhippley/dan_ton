#!/usr/bin/env elixir

# Test script for Q&A database

Mix.install([
  {:exqlite, "~> 0.23"}
])

db_path = "apps/dan_core/priv/db/dan_ton.db"

IO.puts("Testing Exqlite connection...")

case Exqlite.Sqlite3.open(db_path) do
  {:ok, conn} ->
    IO.puts("✓ Database opened successfully")

    # Try to execute a simple query
    sql = "SELECT COUNT(*) FROM documents"
    case Exqlite.Sqlite3.prepare(conn, sql) do
      {:ok, statement} ->
        IO.puts("✓ Statement prepared")

        case Exqlite.Sqlite3.fetch_all(conn, statement) do
          {:ok, rows} ->
            IO.puts("✓ Rows fetched: #{inspect(rows)}")

          {:error, reason} ->
            IO.puts("✗ Failed to fetch: #{inspect(reason)}")
        end

        Exqlite.Sqlite3.release(conn, statement)

      {:error, reason} ->
        IO.puts("✗ Query failed: #{inspect(reason)}")
    end

    Exqlite.Sqlite3.close(conn)
    IO.puts("✓ Database closed")

  {:error, reason} ->
    IO.puts("✗ Failed to open database: #{inspect(reason)}")
end
