import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mayor_game, MayorGame.Repo,
  username: "postgres",
  password: "postgres",
  database: "mayor_game_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mayor_game, MayorGameWeb.Endpoint,
  http: [port: 4002],
  server: false

# don't run the game loop (MayorGame.CityCalculator) in tests; tests call it directly
config :mayor_game, start_game_loop: false

# Print only warnings and errors during test
config :logger, level: :warn

# lower iteration for speed
config :pow, Pow.Ecto.Schema.Password, iterations: 1
