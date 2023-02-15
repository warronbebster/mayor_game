defmodule MayorGame.Repo.Migrations.AddDistributionCenters do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :distribution_centers, :integer, default: 0
    end
  end
end
