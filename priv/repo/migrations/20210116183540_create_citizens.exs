defmodule MayorGame.Repo.Migrations.CreateCitizens do
  use Ecto.Migration

  def change do
    create table(:citizens) do
      add :name, :string, null: false
      add :money, :integer, null: false
      add :info_id, references(:cities, on_delete: :nothing)

      timestamps()
    end

    create index(:citizens, [:info_id])
  end
end
