import Config

# Configure your database
config :mayor_game, MayorGame.Repo,
  username: "postgres",
  password: "postgres",
  database: "mayor_game_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
