defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :city_treasury, :integer, default: 500
      add :town_id, references(:cities, on_delete: :nothing)

      timestamps()
    end

    create index(:details, [:town_id])
  end
end
