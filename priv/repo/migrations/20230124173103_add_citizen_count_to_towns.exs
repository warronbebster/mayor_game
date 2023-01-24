defmodule MayorGame.Repo.Migrations.AddCitizenCountToTowns do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :citizen_count, :integer, default: 0
    end
  end
end
