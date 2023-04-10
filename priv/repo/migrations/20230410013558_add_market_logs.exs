defmodule MayorGame.Repo.Migrations.AddMarketLogs do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :logs_market_sales, :map, default: %{}
      add :logs_market_purchases, :map, default: %{}
    end
  end
end
