defmodule DanCore.TTS.MacSay do
  @moduledoc """
  macOS `say` command TTS adapter.

  Simple adapter using the built-in macOS text-to-speech system.
  Only available on macOS.
  """

  @behaviour DanCore.TTS

  require Logger

  @impl true
  def speak(text, opts \\ []) do
    voice = Keyword.get(opts, :voice, default_voice())

    case System.cmd("say", ["-v", voice, text]) do
      {_, 0} ->
        Logger.debug("MacSay spoke: #{String.slice(text, 0..50)}...")
        :ok

      {error, code} ->
        Logger.error("MacSay failed (#{code}): #{error}")
        {:error, {:say_failed, code}}
    end
  end

  @impl true
  def available? do
    case System.cmd("which", ["say"]) do
      {path, 0} when path != "" -> true
      _ -> false
    end
  end

  @impl true
  def voice_list do
    case System.cmd("say", ["-v", "?"]) do
      {output, 0} ->
        voices =
          output
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(fn line ->
            line
            |> String.split()
            |> List.first()
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, voices}

      _ ->
        {:error, :command_failed}
    end
  end

  @impl true
  def default_voice, do: "Samantha"

  @impl true
  def stop do
    System.cmd("killall", ["say"])
    :ok
  end
end
