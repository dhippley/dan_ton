defmodule DanCore.TTS do
  @moduledoc """
  Behaviour module for Text-to-Speech adapters.
  
  Defines the interface that all TTS implementations must follow.
  Supports multiple backends (Piper, MacSay, etc.) with runtime switching.
  """

  @doc """
  Speaks the given text using the TTS engine.
  
  Returns :ok if speech started successfully, {:error, reason} otherwise.
  """
  @callback speak(text :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}

  @doc """
  Checks if the TTS engine is available on the system.
  """
  @callback available?() :: boolean()

  @doc """
  Lists available voices for the TTS engine.
  """
  @callback voice_list() :: {:ok, [String.t()]} | {:error, term()}

  @doc """
  Gets the default voice for the TTS engine.
  """
  @callback default_voice() :: String.t()

  @doc """
  Stops any currently playing speech.
  """
  @callback stop() :: :ok

  @doc """
  Gets the configured TTS adapter module.
  
  Order of preference:
  1. Application config :tts_adapter
  2. Auto-detect based on platform
  """
  def adapter do
    Application.get_env(:dan_core, :tts_adapter) || detect_adapter()
  end

  @doc """
  Speaks text using the configured adapter.
  """
  def speak(text, opts \\ []) do
    adapter().speak(text, opts)
  end

  @doc """
  Checks if any TTS adapter is available.
  """
  def available? do
    adapter().available?()
  end

  @doc """
  Lists available voices.
  """
  def voice_list do
    adapter().voice_list()
  end

  @doc """
  Gets the default voice.
  """
  def default_voice do
    adapter().default_voice()
  end

  @doc """
  Stops current speech.
  """
  def stop do
    adapter().stop()
  end

  # Private functions

  defp detect_adapter do
    cond do
      DanCore.TTS.Piper.available?() ->
        DanCore.TTS.Piper

      DanCore.TTS.MacSay.available?() ->
        DanCore.TTS.MacSay

      true ->
        DanCore.TTS.Null
    end
  end
end
