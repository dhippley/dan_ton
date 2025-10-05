defmodule DanCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :dan_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {DanCore.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:oban, "~> 2.17"},
      {:swoosh, "~> 1.16"},
      {:dns_cluster, "~> 0.2.0"},
      {:yaml_elixir, "~> 2.9"}
    ]
  end

  defp aliases do
    []
  end
end
