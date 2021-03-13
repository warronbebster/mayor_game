defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :city_treasury, :integer, default: 500
      add :info_id, references(:cities, on_delete: :nothing)
      # housing
      add :single_family_homes, :integer, default: 0
      add :multi_family_homes, :integer, default: 0
      add :homeless_shelter, :integer, default: 0
      add :apartments, :integer, default: 0
      add :micro_apartments, :integer, default: 0
      add :high_rises, :integer, default: 0
      # transit
      add :roads, :integer, default: 0
      add :highways, :integer, default: 0
      add :airports, :integer, default: 0
      add :bus_lines, :integer, default: 0
      add :subway_lines, :integer, default: 0
      # infrastructure
      add :coal_plants, :integer, default: 0
      add :power_plants, :integer, default: 0
      add :wind_turbines, :integer, default: 0
      add :solar_plants, :integer, default: 0
      add :nuclear_plants, :integer, default: 0
      # civic
      add :parks, :integer, default: 0
      add :libraries, :integer, default: 0
      # education
      add :schools, :integer, default: 0
      add :universities, :integer, default: 0
      add :research_labs, :integer, default: 0
      # work
      add :factories, :integer, default: 0
      add :retail, :integer, default: 0
      add :office_buildings, :integer, default: 0
      # entertainment
      add :theatres, :integer, default: 0
      add :arenas, :integer, default: 0

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
