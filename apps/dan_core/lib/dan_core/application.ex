defmodule DanCore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DanCore.Repo,
      {Oban, Application.fetch_env!(:dan_core, Oban)},
      {DNSCluster, query: Application.get_env(:dan_core, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DanCore.PubSub},
      # Demo Runner for Phase 2
      DanCore.Demo.Runner,
      # TTS Speaker for Phase 5
      DanCore.Speaker
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DanCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
