import Config

config :mayor_game,
mail_secret: "3ab294dfbb937aa9065ab365baeac51b"

# Configure your database
config :mayor_game, MayorGame.Repo,
  username: "neon",
  password: "RST2EMsdfk6D",
  database: "neondb",
  hostname: "ep-calm-hall-a5bwuqkv.us-east-2.aws.neon.tech",
  show_sensitive_data_on_connection_error: true,
  ssl: true,
  ssl_opts: [
    server_name_indication: 'ep-calm-hall-a5bwuqkv.us-east-2.aws.neon.tech',
    verify: :verify_none
  ],
  pool_size: 10,
  # this sets dev logging level; set to false, :info, :warn
  log: false
