defmodule MayorGame.Repo do
  use Ecto.Repo,
    otp_app: :mayor_game,
    adapter: Ecto.Adapters.Postgres
end
