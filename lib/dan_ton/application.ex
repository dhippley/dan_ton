defmodule DanTon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DanTonWeb.Telemetry,
      DanTon.Repo,
      {Oban, Application.fetch_env!(:dan_ton, Oban)},
      {DNSCluster, query: Application.get_env(:dan_ton, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DanTon.PubSub},
      # Start a worker by calling: DanTon.Worker.start_link(arg)
      # {DanTon.Worker, arg},
      # Start to serve requests, typically the last entry
      DanTonWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DanTon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DanTonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
