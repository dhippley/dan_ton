defmodule DanTon.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp deps do
    [
      {:styler, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["cmd mix setup"],
      test: ["cmd mix test"]
    ]
  end

  defp releases do
    [
      dan_ton: [
        applications: [
          dan_core: :permanent,
          dan_web: :permanent
        ]
      ]
    ]
  end
end
