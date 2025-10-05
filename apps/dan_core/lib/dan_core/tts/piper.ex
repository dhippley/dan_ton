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
  @models_dir "#{@piper_dir}/models"
  @default_voice "en_US-lessac-medium"

  # Use system-installed piper (via pip)
  defp piper_binary, do: System.find_executable("piper") || "piper"

  @impl true
  def speak(text, opts \\ []) do
    voice = Keyword.get(opts, :voice, @default_voice)
    model_path = Path.join(@models_dir, "#{voice}.onnx")
    config_path = Path.join(@models_dir, "#{voice}.onnx.json")

    cond do
      not File.exists?(model_path) ->
        Logger.warning("Voice model not found: #{voice}")
        {:error, :model_not_found}

      not piper_installed?() ->
        Logger.warning("Piper not found. Install with: pip install piper-tts")
        {:error, :binary_not_found}

      true ->
        execute_piper(text, model_path, config_path)
    end
  end

  defp execute_piper(text, model_path, config_path) do
    # Use temp file approach to avoid broken pipe errors
    temp_file = Path.join(System.tmp_dir!(), "piper_#{:os.system_time(:millisecond)}.wav")

    args = [
      "--model",
      model_path,
      "--config",
      config_path,
      "--output_file",
      temp_file
    ]

    try do
      # Generate audio to file, then play it
      case System.cmd("sh", ["-c", "echo #{escape_text(text)} | #{piper_binary()} #{Enum.join(args, " ")}"]) do
        {_, 0} ->
          Logger.debug("Piper TTS generated audio: #{String.slice(text, 0..50)}...")

          # Play the generated file
          case play_audio_file(temp_file) do
            :ok ->
              # Clean up temp file
              File.rm(temp_file)
              :ok

            error ->
              File.rm(temp_file)
              error
          end

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

  defp play_audio_file(file_path) do
    case os_type() do
      :macos ->
        case System.cmd("afplay", [file_path]) do
          {_, 0} -> :ok
          {error, code} ->
            Logger.error("afplay failed (#{code}): #{error}")
            {:error, {:playback_failed, code}}
        end

      :linux ->
        case System.cmd("aplay", [file_path]) do
          {_, 0} -> :ok
          {error, code} ->
            Logger.error("aplay failed (#{code}): #{error}")
            {:error, {:playback_failed, code}}
        end

      _ ->
        {:error, :unsupported_platform}
    end
  end

  @impl true
  def available? do
    piper_installed?() and File.exists?(@models_dir)
  end

  defp piper_installed? do
    case System.cmd("which", ["piper"]) do
      {path, 0} when path != "" -> true
      _ -> false
    end
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
  Sets up Piper by installing via pip and downloading voice models.

  This should be run once during installation:
      mix piper.setup
  """
  def setup do
    Logger.info("Setting up Piper TTS...")

    with :ok <- check_or_install_piper(),
         :ok <- create_directories(),
         :ok <- download_voice_model(@default_voice) do
      Logger.info("Piper setup complete!")
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Piper setup failed: #{inspect(reason)}")
        error
    end
  end

  defp check_or_install_piper do
    if piper_installed?() do
      Logger.info("Piper is already installed")
      :ok
    else
      Logger.info("Piper not found. Attempting to install via pip...")

      case System.cmd("pip3", ["install", "piper-tts"]) do
        {_, 0} ->
          Logger.info("Piper installed successfully")
          :ok

        {error, code} ->
          Logger.error("Failed to install Piper (#{code}): #{error}")
          Logger.info("Please install manually: pip3 install piper-tts")
          {:error, :install_failed}
      end
    end
  end

  @doc """
  Downloads a specific voice model using Piper's built-in downloader.
  """
  def download_voice_model(voice) do
    Logger.info("Downloading voice model: #{voice}")

    # Use piper's built-in download_voices command
    case System.cmd("python3", ["-m", "piper.download_voices", "--download-dir", @models_dir, voice]) do
      {output, 0} ->
        Logger.info("Voice model downloaded: #{voice}")
        Logger.debug(output)

        # The downloaded files need to be renamed to match our expected format
        # Piper downloads to en/en_US/lessac/medium/en_US-lessac-medium.onnx
        # We need it at models/en_US-lessac-medium.onnx
        rename_downloaded_model(voice)

      {error, code} ->
        Logger.error("Failed to download voice (#{code}): #{error}")
        {:error, :download_failed}
    end
  end

  defp rename_downloaded_model(voice) do
    # Piper downloads to a nested directory structure
    # Try to find and copy the files to our models directory
    possible_paths = [
      Path.join([@models_dir, "en", "en_US", voice, "en_US-#{voice}.onnx"]),
      Path.join([@models_dir, voice, "en_US-#{voice}.onnx"]),
      Path.join([@models_dir, "en_US-#{voice}.onnx"])
    ]

    # Check which path exists and copy if needed
    Enum.find_value(possible_paths, :ok, fn src_path ->
      if File.exists?(src_path) do
        dest_onnx = Path.join(@models_dir, "#{voice}.onnx")
        dest_json = Path.join(@models_dir, "#{voice}.onnx.json")

        src_json = String.replace(src_path, ".onnx", ".onnx.json")

        unless File.exists?(dest_onnx) do
          File.cp!(src_path, dest_onnx)
        end

        if File.exists?(src_json) and not File.exists?(dest_json) do
          File.cp!(src_json, dest_json)
        end

        :ok
      else
        nil
      end
    end)
  end

  # Private functions

  defp create_directories do
    File.mkdir_p(@piper_dir)
    File.mkdir_p(@models_dir)
    :ok
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

  defp voice_model_url(voice) do
    # Use python -m piper.download_voices to download voices
    "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/#{voice}/en_US-#{voice}.onnx"
  end

  defp voice_config_url(voice) do
    "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/#{voice}/en_US-#{voice}.onnx.json"
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
