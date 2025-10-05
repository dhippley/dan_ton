defmodule Mix.Tasks.Dan.Validate do
  @moduledoc """
  Validate demo script YAML files.

  Usage:
      mix dan.validate [path]

  Examples:
      mix dan.validate                                    # Validate all scripts in demo/scripts/
      mix dan.validate demo/scripts/example_demo.yml     # Validate specific file
      mix dan.validate demo/scripts/                      # Validate directory

  This checks for:
  - Required fields (name, steps)
  - Valid step types
  - Required parameters for each step type
  - URL and filename formats
  - Recovery step validity
  """

  use Mix.Task
  require Logger

  alias DanCore.Demo.Validator

  @shortdoc "Validate demo script files"

  @impl Mix.Task
  def run([]) do
    Mix.Task.run("app.start")
    validate_default()
  end

  def run([path]) do
    Mix.Task.run("app.start")

    cond do
      File.dir?(path) ->
        validate_directory(path)

      File.exists?(path) ->
        validate_file(path)

      true ->
        IO.puts("❌ Error: Path not found: #{path}")
        exit({:shutdown, 1})
    end
  end

  defp validate_default do
    IO.puts("\n🔍 Validating demo scripts...\n")

    case Validator.validate_directory("demo/scripts") do
      :ok ->
        IO.puts("✅ All scripts are valid!\n")

      {:error, :validation_failed} ->
        exit({:shutdown, 1})

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}\n")
        exit({:shutdown, 1})
    end
  end

  defp validate_directory(path) do
    IO.puts("\n🔍 Validating scripts in #{path}...\n")

    case Validator.validate_directory(path) do
      :ok ->
        IO.puts("✅ All scripts are valid!\n")

      {:error, :validation_failed} ->
        exit({:shutdown, 1})

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}\n")
        exit({:shutdown, 1})
    end
  end

  defp validate_file(path) do
    IO.puts("\n🔍 Validating #{path}...\n")

    case Validator.validate_file(path) do
      :ok ->
        IO.puts("✅ Script is valid!\n")

      {:error, errors} ->
        Validator.print_errors(errors)
        exit({:shutdown, 1})
    end
  end
end
