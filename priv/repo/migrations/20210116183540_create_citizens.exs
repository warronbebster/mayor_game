defmodule MayorGame.Repo.Migrations.CreateCitizens do
  use Ecto.Migration

  def change do
    create table(:citizens) do
      add :name, :string, null: false
      add :money, :integer, null: false
      add :lastMoved, :naive_datetime
      add :city_id, references(:cities, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:citizens, [:city])
  end
end
