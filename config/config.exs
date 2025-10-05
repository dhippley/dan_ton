# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dan_core,
  ecto_repos: [DanCore.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :dan_web, DanWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DanWeb.ErrorHTML, json: DanWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DanCore.PubSub,
  live_view: [signing_salt: "5MxFfY/2"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dan_core, DanCore.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  dan_ton: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/dan_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  dan_ton: [
    args: ~w(
      --input=apps/dan_web/assets/css/app.css
      --output=apps/dan_web/priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban
config :dan_core, Oban,
  repo: DanCore.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
