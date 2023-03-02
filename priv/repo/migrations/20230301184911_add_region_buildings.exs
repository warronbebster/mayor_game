defmodule MayorGame.Repo.Migrations.AddRegionBuildings do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :lumber_yards, :integer, default: 0
      add :fisheries, :integer, default: 0
      add :resorts, :integer, default: 0
      add :ski_resorts, :integer, default: 0
      add :lithium_mines, :integer, default: 0
      add :farms, :integer, default: 0
      add :salt_farms, :integer, default: 0
      add :quarries, :integer, default: 0
      add :reservoirs, :integer, default: 0
    end
  end
end
