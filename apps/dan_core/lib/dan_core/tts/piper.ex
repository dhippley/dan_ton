defmodule DanCore.TTS.Piper do
  @moduledoc """
  Piper TTS adapter using local neural text-to-speech.
  
  Piper is a fast, high-quality TTS system that runs completely offline.
  It requires:
  - Piper binary (downloaded automatically)
  - Voice model files (.onnx + .json)
  
  For macOS ARM64, downloads the appropriate binary and voice models.
  """

  @behaviour DanCore.TTS

  require Logger

  @piper_dir "apps/dan_core/priv/piper"
  @piper_binary "#{@piper_dir}/piper"
  @models_dir "#{@piper_dir}/models"
  @default_voice "en_US-lessac-medium"

  @impl true
  def speak(text, opts \\ []) do
    voice = Keyword.get(opts, :voice, @default_voice)
    model_path = Path.join(@models_dir, "#{voice}.onnx")
    config_path = Path.join(@models_dir, "#{voice}.onnx.json")

    cond do
      not File.exists?(model_path) ->
        Logger.warning("Voice model not found: #{voice}")
        {:error, :model_not_found}

      not File.exists?(@piper_binary) ->
        Logger.warning("Piper binary not found at #{@piper_binary}")
        {:error, :binary_not_found}

      true ->
        execute_piper(text, model_path, config_path)
    end
  end

  defp execute_piper(text, model_path, config_path) do

    # Execute Piper with text input
    args = [
      "--model",
      model_path,
      "--config",
      config_path,
      "--output-raw"
    ]

    try do
      # Pipe text to Piper, which outputs raw audio that we pipe to afplay (macOS) or aplay (Linux)
      case System.cmd("sh", [
             "-c",
             "echo #{escape_text(text)} | #{@piper_binary} #{Enum.join(args, " ")} | #{audio_player()}"
           ]) do
        {_, 0} ->
          Logger.debug("Piper TTS spoke: #{String.slice(text, 0..50)}...")
          :ok

        {error, code} ->
          Logger.error("Piper TTS failed (#{code}): #{error}")
          {:error, {:piper_failed, code}}
      end
    rescue
      e ->
        Logger.error("Piper TTS exception: #{inspect(e)}")
        {:error, e}
    end
  end

  @impl true
  def available? do
    File.exists?(@piper_binary) && File.exists?(@models_dir)
  end

  @impl true
  def voice_list do
    if File.exists?(@models_dir) do
      voices =
        Path.wildcard("#{@models_dir}/*.onnx")
        |> Enum.map(&Path.basename(&1, ".onnx"))
        |> Enum.sort()

      {:ok, voices}
    else
      {:error, :models_not_found}
    end
  end

  @impl true
  def default_voice, do: @default_voice

  @impl true
  def stop do
    # Kill any running Piper or audio player processes
    System.cmd("pkill", ["-f", "piper"])
    System.cmd("pkill", ["-f", "afplay"])
    System.cmd("pkill", ["-f", "aplay"])
    :ok
  end

  @doc """
  Sets up Piper by downloading the binary and voice models.
  
  This should be run once during installation:
      mix piper.setup
  """
  def setup do
    Logger.info("Setting up Piper TTS...")

    with :ok <- create_directories(),
         :ok <- download_binary(),
         :ok <- download_voice_model(@default_voice) do
      Logger.info("Piper setup complete!")
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Piper setup failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Downloads a specific voice model.
  """
  def download_voice_model(voice) do
    Logger.info("Downloading voice model: #{voice}")

    model_url = voice_model_url(voice)
    config_url = voice_config_url(voice)

    model_path = Path.join(@models_dir, "#{voice}.onnx")
    config_path = Path.join(@models_dir, "#{voice}.onnx.json")

    with :ok <- download_file(model_url, model_path),
         :ok <- download_file(config_url, config_path) do
      Logger.info("Voice model downloaded: #{voice}")
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Failed to download voice model: #{inspect(reason)}")
        error
    end
  end

  # Private functions

  defp create_directories do
    File.mkdir_p(@piper_dir)
    File.mkdir_p(@models_dir)
    :ok
  end

  defp download_binary do
    if File.exists?(@piper_binary) do
      Logger.info("Piper binary already exists")
      :ok
    else
      Logger.info("Downloading Piper binary...")
      url = piper_binary_url()

      case download_file(url, @piper_binary) do
        :ok ->
          File.chmod(@piper_binary, 0o755)
          Logger.info("Piper binary downloaded and made executable")
          :ok

        error ->
          error
      end
    end
  end

  defp download_file(url, dest_path) do
    Logger.debug("Downloading: #{url}")

    case Req.get(url, receive_timeout: 300_000) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(dest_path, body)
        :ok

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp piper_binary_url do
    # Detect platform and return appropriate binary URL
    case {os_type(), arch()} do
      {:macos, :aarch64} ->
        "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_macos_arm64.tar.gz"

      {:macos, :x86_64} ->
        "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_macos_x86_64.tar.gz"

      {:linux, :aarch64} ->
        "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_linux_aarch64.tar.gz"

      {:linux, :x86_64} ->
        "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_linux_x86_64.tar.gz"

      other ->
        Logger.error("Unsupported platform: #{inspect(other)}")
        nil
    end
  end

  defp voice_model_url(voice) do
    "https://huggingface.co/rhasspy/piper-voices/resolve/main/#{voice}.onnx"
  end

  defp voice_config_url(voice) do
    "https://huggingface.co/rhasspy/piper-voices/resolve/main/#{voice}.onnx.json"
  end

  defp os_type do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, :linux} -> :linux
      other -> other
    end
  end

  defp arch do
    case :erlang.system_info(:system_architecture) do
      ~c"aarch64" ++ _ -> :aarch64
      ~c"arm64" ++ _ -> :aarch64
      ~c"x86_64" ++ _ -> :x86_64
      arch -> String.to_atom(List.to_string(arch))
    end
  end

  defp audio_player do
    case os_type() do
      :macos -> "afplay -"
      :linux -> "aplay -r 22050 -f S16_LE -t raw -"
      _ -> "cat > /dev/null"
    end
  end

  defp escape_text(text) do
    # Escape text for shell
    text
    |> String.replace("\"", "\\\"")
    |> String.replace("'", "\\'")
    |> then(&"\"#{&1}\"")
  end
end
