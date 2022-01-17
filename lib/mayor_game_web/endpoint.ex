defmodule MayorGameWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :mayor_game

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_mayor_game_key",
    signing_salt: "kNrd8ApH2OXJhnjBBnJz7dXuy5qjP2Zh"
  ]

  socket "/socket", MayorGameWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  # so it wants me to put the below line, but the one above might work also?
  # oh there's where those errors were coming from

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :mayor_game,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :mayor_game
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options

  plug Pow.Plug.Session,
    otp_app: :mayor_game,
    cache_store_backend: Pow.Store.Backend.MnesiaCache,
    # add session token length
    session_ttl_renewal: :timer.minutes(3),
    credentials_cache_store: {Pow.Store.CredentialsCache, ttl: :timer.minutes(30)}

  # make user sessions persistent with a cookie
  plug PowPersistentSession.Plug.Cookie

  # last thing is to send the conn to the router
  plug MayorGameWeb.Router
end
