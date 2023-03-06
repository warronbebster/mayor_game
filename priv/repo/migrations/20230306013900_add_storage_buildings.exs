defmodule MayorGame.Repo.Migrations.AddStorageBuildings do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :wood_warehouses, :integer, default: 0
      add :fish_tanks, :integer, default: 0
      add :lithium_vats, :integer, default: 0
      add :salt_sheds, :integer, default: 0
      add :rock_yards, :integer, default: 0
      add :water_tanks, :integer, default: 0
    end
  end
end
