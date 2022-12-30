# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mayor_game,
  ecto_repos: [MayorGame.Repo]

# Configures the endpoint
config :mayor_game, MayorGameWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "0mKur1+t9xUhzGesuvASZlGAu1N+itFCwWHlLYL2bxxz9XVtWxI6b+sy4KKGK2+J",
  render_errors: [view: MayorGameWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: MayorGame.PubSub,
  live_view: [signing_salt: "kNrd8ApH2OXJhnjBBnJz7dXuy5qjP2Zh"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mayor_game, :pow,
  user: MayorGame.Auth.User,
  repo: MayorGame.Repo,
  web_module: MayorGameWeb,
  extensions: [PowPersistentSession, PowResetPassword],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: MayorGameWeb.Pow.Mailer

config :mayor_game, MayorGameWeb.Pow.Mailer,
  adapter: Swoosh.Adapters.Mailjet,
  # api_key: "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"
  api_key: "71dfa3a267a5a221900658d68768d405",
  secret: "9a5c8d20c0f1f141a91067190500b86b"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.2.4",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
