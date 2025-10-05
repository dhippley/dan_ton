defmodule DanCore.Demo.Parser do
  @moduledoc """
  Parses YAML demo scenario files into structured Elixir maps.

  Expected YAML structure:
  ```yaml
  name: "Demo Name"
  env:
    base_url: "http://localhost:4000"
  steps:
    - goto: "/path"
    - click: { role: "button", name: "Submit" }
    - fill: { field: "email", value: "test@example.com" }
    - assert_text: "Success"
  recover:
    - reload: true
    - take_screenshot: true
  ```
  """

  @valid_step_types ~w(goto click fill assert_text reload take_screenshot wait pause narrate)

  @type scenario :: %{
          name: String.t(),
          env: map(),
          steps: list(map()),
          recover: list(map())
        }

  @doc """
  Parses a YAML file and returns a structured scenario map.

  ## Examples

      iex> Parser.parse_file("demo/scripts/checkout.yml")
      {:ok, %{name: "Checkout Demo", env: %{...}, steps: [...]}}

      iex> Parser.parse_file("invalid.yml")
      {:error, "File not found"}
  """
  @spec parse_file(String.t()) :: {:ok, scenario()} | {:error, String.t()}
  def parse_file(path) do
    with true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, parsed} <- parse_content(content) do
      {:ok, parsed}
    else
      false -> {:error, "File not found: #{path}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parses YAML content string into a scenario map.
  """
  @spec parse_content(String.t()) :: {:ok, scenario()} | {:error, String.t()}
  def parse_content(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, data} ->
        validate_and_structure(data)

      {:error, %{message: message}} ->
        {:error, "YAML parsing error: #{message}"}

      {:error, reason} ->
        {:error, "YAML parsing error: #{inspect(reason)}"}
    end
  end

  # Private Functions

  defp validate_and_structure(data) when is_map(data) do
    with {:ok, name} <- extract_name(data),
         {:ok, env} <- extract_env(data),
         {:ok, steps} <- extract_steps(data),
         {:ok, recover} <- extract_recover(data) do
      scenario = %{
        name: name,
        env: env,
        steps: steps,
        recover: recover
      }

      {:ok, scenario}
    end
  end

  defp validate_and_structure(_data) do
    {:error, "Invalid YAML structure: expected a map at root level"}
  end

  defp extract_name(%{"name" => name}) when is_binary(name) do
    {:ok, name}
  end

  defp extract_name(_) do
    {:error, "Missing or invalid 'name' field"}
  end

  defp extract_env(%{"env" => env}) when is_map(env) do
    {:ok, env}
  end

  defp extract_env(_) do
    {:ok, %{}}
  end

  defp extract_steps(%{"steps" => steps}) when is_list(steps) do
    validated_steps =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {step, index} ->
        case validate_step(step, index) do
          {:ok, validated} -> validated
          {:error, reason} -> {:error, "Step #{index}: #{reason}"}
        end
      end)

    errors = Enum.filter(validated_steps, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, validated_steps}
    else
      error_messages = Enum.map(errors, fn {:error, msg} -> msg end)
      {:error, "Step validation errors:\n" <> Enum.join(error_messages, "\n")}
    end
  end

  defp extract_steps(_) do
    {:error, "Missing or invalid 'steps' field (must be a list)"}
  end

  defp extract_recover(%{"recover" => recover}) when is_list(recover) do
    {:ok, recover}
  end

  defp extract_recover(_) do
    {:ok, []}
  end

  defp validate_step(step, index) when is_map(step) do
    # Each step should have exactly one action key
    case Map.keys(step) do
      [action_key] ->
        action_type = to_string(action_key)

        if action_type in @valid_step_types do
          {:ok, %{type: action_type, params: Map.get(step, action_key), index: index}}
        else
          {:error, "Unknown step type '#{action_type}'. Valid types: #{Enum.join(@valid_step_types, ", ")}"}
        end

      [] ->
        {:error, "Empty step definition"}

      keys ->
        {:error, "Step should have exactly one action, found: #{inspect(keys)}"}
    end
  end

  defp validate_step(_step, _index) do
    {:error, "Step must be a map"}
  end

  @doc """
  Returns a list of valid step types.
  """
  def valid_step_types, do: @valid_step_types
end
