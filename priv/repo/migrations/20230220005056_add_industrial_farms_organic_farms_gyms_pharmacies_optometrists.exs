defmodule MayorGame.Repo.Migrations.AddIndustrialFarmsOrganicFarmsGymsPharmaciesOptometrists do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :industrial_farms, :integer, default: 0
      add :organic_farms, :integer, default: 0
      add :gyms, :integer, default: 0
      add :pharmacies, :integer, default: 0
      add :optometrists, :integer, default: 0
    end
  end
end
