defmodule MayorGame.Repo.Migrations.AddGasPlants do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :natural_gas_plants, :integer, default: 0
    end
  end
end
