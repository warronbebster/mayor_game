# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
