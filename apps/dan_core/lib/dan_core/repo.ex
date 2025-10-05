defmodule DanCore.Repo do
  use Ecto.Repo,
    otp_app: :dan_ton,
    adapter: Ecto.Adapters.Postgres
end
