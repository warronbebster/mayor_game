defmodule MayorGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      MayorGame.Repo,
      # Start the Telemetry supervisor
      MayorGameWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: MayorGame.PubSub},
      # HTTP client pool, used by Swoosh to send emails through Resend's API
      {Finch, name: MayorGame.Finch},
      # Start the Endpoint (http/https)
      MayorGameWeb.Endpoint,

      # clean up old records a la https://github.com/ZennerIoT/pow_postgres_store
      {Pow.Postgres.Store.AutoDeleteExpired, [interval: :timer.hours(1)]}
    ]

    # the game loop, running on world 1. Disabled in tests (config/test.exs).
    children =
      if Application.get_env(:mayor_game, :start_game_loop, true),
        do: children ++ [{MayorGame.CityCalculator, 1}],
        else: children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MayorGame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MayorGameWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
