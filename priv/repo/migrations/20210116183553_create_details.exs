defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :roads, :integer, default: 0
      add :schools, :integer, default: 0
      add :houses, :integer, default: 0
      add :parks, :integer, default: 0
      add :libraries, :integer, default: 0
      add :universities, :integer, default: 0
      add :airports, :integer, default: 0
      add :office_buildings, :integer, default: 0
      add :apartments, :integer, default: 0
      add :city_treasury, :integer, default: 500
      add :info_id, references(:cities, on_delete: :nothing)

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
