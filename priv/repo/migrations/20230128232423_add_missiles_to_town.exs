defmodule MayorGame.Repo.Migrations.AddCitizenCountToTowns do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :missiles, :integer, default: 0
    end
  end
end
