defmodule DanCore.QA.Ollama do
  @moduledoc """
  Client for communicating with Ollama LLM API.
  
  Provides interface for text generation using local Ollama models.
  Default model: llama3.1:8b
  """

  require Logger

  @default_model "llama3.1:8b"
  @default_base_url "http://localhost:11434"
  @timeout 30_000

  @doc """
  Generates text completion using Ollama.
  
  Options:
  - `:model` - Model to use (default: "llama3.1:8b")
  - `:temperature` - Sampling temperature (default: 0.7)
  - `:max_tokens` - Maximum tokens to generate (default: 500)
  - `:stream` - Whether to stream response (default: false)
  """
  def generate(prompt, context \\ "", opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 500)

    full_prompt = build_prompt(prompt, context)

    request_body = %{
      model: model,
      prompt: full_prompt,
      options: %{
        temperature: temperature,
        num_predict: max_tokens
      },
      stream: false
    }

    Logger.debug("Calling Ollama with model: #{model}")

    case call_api("/api/generate", request_body) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Ollama API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("Ollama request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Checks if Ollama is available and responsive.
  """
  def available? do
    case Req.get("#{base_url()}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  @doc """
  Lists available models in Ollama.
  """
  def list_models do
    case call_api("/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        model_names = Enum.map(models, & &1["name"])
        {:ok, model_names}

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a specific model is available locally.
  """
  def model_exists?(model_name) do
    case list_models() do
      {:ok, models} -> model_name in models
      {:error, _} -> false
    end
  end

  @doc """
  Pulls a model from Ollama registry.
  
  This is a long-running operation that may take several minutes.
  """
  def pull_model(model_name) do
    Logger.info("Pulling model: #{model_name}")

    request_body = %{
      name: model_name,
      stream: false
    }

    # Longer timeout for model downloads
    case call_api("/api/pull", request_body, timeout: 600_000) do
      {:ok, %{status: 200}} ->
        Logger.info("Model #{model_name} pulled successfully")
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to pull model: #{status} - #{inspect(body)}")
        {:error, {:pull_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp build_prompt(question, "") do
    """
    Answer the following question concisely and accurately:

    #{question}
    """
  end

  defp build_prompt(question, context) do
    """
    You are a helpful assistant answering questions about documentation.
    Use the following context to answer the question. If the answer is not in the context, say so.

    Context:
    #{context}

    Question: #{question}

    Answer:
    """
  end

  defp call_api(endpoint, body \\ nil, opts \\ []) do
    url = base_url() <> endpoint
    timeout = Keyword.get(opts, :timeout, @timeout)

    request_opts = [
      receive_timeout: timeout,
      retry: false
    ]

    if body do
      Req.post(url, [json: body] ++ request_opts)
    else
      Req.get(url, request_opts)
    end
  end

  defp parse_response(%{"response" => response}) when is_binary(response) do
    {:ok, String.trim(response)}
  end

  defp parse_response(body) do
    Logger.warning("Unexpected Ollama response format: #{inspect(body)}")
    {:error, :invalid_response}
  end

  defp base_url do
    Application.get_env(:dan_core, :ollama_base_url, @default_base_url)
  end
end
