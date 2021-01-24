defmodule MayorGameWeb.Router do
  use MayorGameWeb, :router
  # Pow route macros
  use Pow.Phoenix.Router

  # create pipeline for general browser
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # :put_root_layout ensures that LiveView layouts and plain Phoenix layouts use a common template as their basis.
    plug :put_root_layout, {MayorGameWeb.LayoutView, :root}
  end

  # add pipeline for protected resources
  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :browser

    # honestly no idea what this is doing
    pow_routes()
  end

  scope "/", MayorGameWeb do
    pipe_through :browser

    get "/", PageController, :index

    live "/cities/:info_id/users/:user_id", CityLive, as: :city
  end

  # Make city routes protected by requiring authentication
  # don't need to do this tho
  # scope "/", MayorGameWeb do
  #   pipe_through [:browser, :protected]

  #   # don't think we made this yet
  #   # resources "/cities", CityController

  #   live "/cities/:info_id/users/:user_id", CityLive, as: :city
  # end

  # Other scopes may use custom stacks.
  # scope "/api", MayorGameWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MayorGameWeb.Telemetry
    end
  end
end
