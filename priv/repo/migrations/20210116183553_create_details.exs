defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :city_treasury, :integer, default: 500
      add :info_id, references(:cities, on_delete: :nothing)
      # housing
      add :houses, :integer, default: 0
      add :apartments, :integer, default: 0
      # transit
      add :roads, :integer, default: 0
      add :airports, :integer, default: 0
      add :bus_lines, :integer, default: 0
      add :subway_lines, :integer, default: 0
      # civic
      add :parks, :integer, default: 0
      add :libraries, :integer, default: 0
      # education
      add :schools, :integer, default: 0
      add :universities, :integer, default: 0
      # work
      add :factories, :integer, default: 0
      add :office_buildings, :integer, default: 0
      # entertainment
      add :theatres, :integer, default: 0
      add :arenas, :integer, default: 0

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
