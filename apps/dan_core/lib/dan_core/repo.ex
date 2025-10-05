defmodule DanCore.Repo do
  use Ecto.Repo,
    otp_app: :dan_core,
    adapter: Ecto.Adapters.Postgres
end
