defmodule MayorGame.Repo.Migrations.CreateCitizens do
  use Ecto.Migration

  def change do
    create table(:citizens) do
      add :name, :string, null: false
      add :money, :integer, null: false, default: 0
      add :age, :integer, null: false, default: 0
      add :education, :integer, null: false, default: 0
      add :job, :integer, null: false, default: 0
      add :has_car, :boolean, default: false
      add :last_moved, :integer, default: 0

      # adds a town_id column to the :citizens table which references an entry in the :cities table.
      add :town_id, references(:cities, on_delete: :nothing)

      timestamps()
    end

    create index(:citizens, [:town_id])
  end
end
