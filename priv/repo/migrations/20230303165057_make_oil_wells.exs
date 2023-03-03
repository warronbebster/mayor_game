defmodule MayorGame.Repo.Migrations.MakeOilWells do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :oil_wells, :integer, default: 0
    end
  end
end
