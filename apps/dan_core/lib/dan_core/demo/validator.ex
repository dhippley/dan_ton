defmodule DanCore.Demo.Validator do
  @moduledoc """
  Validates demo scenario YAML files for correctness.

  Checks:
  - Required fields are present
  - Step types are valid
  - Parameters match step types
  - URLs are properly formatted
  - Recovery steps are valid
  """

  require Logger

  @valid_step_types ~w(goto click fill assert_text wait take_screenshot reload narrate pause)

  @required_fields ~w(name steps)

  @step_schemas %{
    "goto" => [:url],
    "click" => [:selector],
    "fill" => [:selector, :value],
    "assert_text" => [:text],
    "wait" => [:duration],
    "take_screenshot" => [:filename],
    "reload" => []
  }

  @doc """
  Validates a scenario struct.

  Returns :ok if valid, {:error, reasons} if invalid.
  """
  def validate_scenario(%{name: _, steps: steps} = scenario) when is_list(steps) do
    errors = []

    # Validate scenario structure
    errors =
      if String.trim(scenario.name) == "" do
        ["Scenario name cannot be empty" | errors]
      else
        errors
      end

    # Validate steps
    step_errors =
      steps
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {step, index} ->
        validate_step(step, index)
      end)

    errors = errors ++ step_errors

    # Validate recovery steps if present
    recovery_errors =
      if recovery = Map.get(scenario, :recovery) do
        recovery
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {step, index} ->
          validate_step(step, index, "recovery")
        end)
      else
        []
      end

    errors = errors ++ recovery_errors

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  def validate_scenario(_) do
    {:error, ["Invalid scenario structure: missing name or steps"]}
  end

  @doc """
  Validates a YAML file containing a scenario.
  """
  def validate_file(path) do
    case DanCore.Demo.Parser.parse_file(path) do
      {:ok, scenario} ->
        validate_scenario(scenario)

      {:error, reason} ->
        {:error, ["Failed to parse file: #{inspect(reason)}"]}
    end
  end

  # Private functions

  defp validate_step(step, index, prefix \\ "step") do
    errors = []

    # Check step has type
    errors =
      if type = Map.get(step, :type) do
        # Check type is valid
        if type in @valid_step_types do
          errors
        else
          ["#{prefix} #{index}: Invalid type '#{type}'. Must be one of: #{Enum.join(@valid_step_types, ", ")}" | errors]
        end
      else
        ["#{prefix} #{index}: Missing 'type' field" | errors]
      end

    # Validate parameters for the step type
    if type = Map.get(step, :type) do
      param_errors = validate_step_params(step, type, index, prefix)
      errors ++ param_errors
    else
      errors
    end
  end

  defp validate_step_params(step, type, index, prefix) do
    required_params = Map.get(@step_schemas, type, [])
    errors = []

    # Check required parameters
    errors =
      Enum.reduce(required_params, errors, fn param, acc ->
        value = Map.get(step, param)

        if Map.has_key?(step, param) and value != nil and
             String.trim(to_string(value)) != "" do
          acc
        else
          ["#{prefix} #{index}: Missing required parameter '#{param}' for type '#{type}'" | acc]
        end
      end)

    # Validate specific parameter formats
    errors = errors ++ validate_param_formats(step, type, index, prefix)

    errors
  end

  defp validate_param_formats(step, type, index, prefix) do
    errors = []

    # Validate URL format for goto steps
    errors =
      if type == "goto" do
        case Map.get(step, :url) do
          url when is_binary(url) ->
            if valid_url?(url) do
              errors
            else
              ["#{prefix} #{index}: Invalid URL format: #{url}" | errors]
            end

          _ ->
            errors
        end
      else
        errors
      end

    # Validate duration for wait steps
    errors =
      if type == "wait" do
        case Map.get(step, :duration) do
          duration when is_integer(duration) and duration > 0 ->
            errors

          _ ->
            [
              "#{prefix} #{index}: Invalid duration. Must be positive integer (milliseconds)"
              | errors
            ]
        end
      else
        errors
      end

    # Validate filename for take_screenshot
    errors =
      if type == "take_screenshot" do
        case Map.get(step, :filename) do
          filename when is_binary(filename) ->
            if valid_filename?(filename) do
              errors
            else
              ["#{prefix} #{index}: Invalid filename: #{filename}" | errors]
            end

          _ ->
            errors
        end
      else
        errors
      end

    errors
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and uri.host != nil
  end

  defp valid_url?(_), do: false

  defp valid_filename?(filename) when is_binary(filename) do
    String.match?(filename, ~r/^[a-zA-Z0-9_\-\.]+$/) &&
      String.length(filename) > 0 &&
      String.length(filename) < 256
  end

  defp valid_filename?(_), do: false

  @doc """
  Prints validation errors in a human-readable format.
  """
  def print_errors(errors) when is_list(errors) do
    IO.puts("\n❌ Validation Errors:\n")

    Enum.each(errors, fn error ->
      IO.puts("  • #{error}")
    end)

    IO.puts("")
  end

  @doc """
  Validates all demo scripts in a directory.
  """
  def validate_directory(dir_path \\ "demo/scripts") do
    case File.ls(dir_path) do
      {:ok, files} ->
        results =
          files
          |> Enum.filter(&String.ends_with?(&1, ".yml"))
          |> Enum.map(fn file ->
            path = Path.join(dir_path, file)
            {path, validate_file(path)}
          end)

        valid_count = Enum.count(results, fn {_, result} -> result == :ok end)
        total_count = length(results)

        IO.puts("\n📋 Validation Results:\n")

        Enum.each(results, fn {path, result} ->
          case result do
            :ok ->
              IO.puts("  ✓ #{path}")

            {:error, errors} ->
              IO.puts("  ✗ #{path}")

              Enum.each(errors, fn error ->
                IO.puts("      - #{error}")
              end)
          end
        end)

        IO.puts("\n#{valid_count}/#{total_count} scripts valid\n")

        if valid_count == total_count, do: :ok, else: {:error, :validation_failed}

      {:error, reason} ->
        {:error, "Failed to list directory: #{inspect(reason)}"}
    end
  end
end
