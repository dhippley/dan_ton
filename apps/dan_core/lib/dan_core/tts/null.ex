defmodule DanCore.TTS.Null do
  @moduledoc """
  Null TTS adapter that does nothing.
  
  Used as a fallback when no TTS system is available.
  Logs warnings but doesn't fail.
  """

  @behaviour DanCore.TTS

  require Logger

  @impl true
  def speak(text, _opts \\ []) do
    Logger.warning("No TTS available. Would speak: #{String.slice(text, 0..50)}...")
    :ok
  end

  @impl true
  def available?, do: false

  @impl true
  def voice_list, do: {:ok, []}

  @impl true
  def default_voice, do: "none"

  @impl true
  def stop, do: :ok
end
