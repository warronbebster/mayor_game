use Mix.Config

# Configure your database
config :mayor_game, MayorGame.Repo,
  username: "postgres",
  password: "postgres",
  database: "mayor_game_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  # this sets dev logging level; set to false, :info, :warn
  log: :warn
