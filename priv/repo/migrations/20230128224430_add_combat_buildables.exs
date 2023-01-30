defmodule MayorGame.Repo.Migrations.AddCombatBuildables do
  use Ecto.Migration

  def change do
    create table(:air_bases) do
      add :details_id, references(:details)

      timestamps()
    end

    create index(:air_bases, [:details_id])
  end
end
