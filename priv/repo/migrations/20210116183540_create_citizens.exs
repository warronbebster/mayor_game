defmodule MayorGame.Repo.Migrations.CreateCitizens do
  use Ecto.Migration

  def change do
    create table(:citizens) do
      add :name, :string
      add :money, :integer
      add :lastMoved, :naive_datetime
      add :city, references(:cities, on_delete: :nothing)

      timestamps()
    end

    create index(:citizens, [:city])
  end
end
