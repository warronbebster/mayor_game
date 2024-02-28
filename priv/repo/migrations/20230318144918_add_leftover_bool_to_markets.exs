defmodule MayorGame.Repo.Migrations.AddLeftoverBoolToMarkets do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :sell_excess, :boolean, default: false
    end
  end
end
