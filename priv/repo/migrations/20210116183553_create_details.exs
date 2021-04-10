defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    create table(:details) do
      add :city_treasury, :integer, default: 500
      add :info_id, references(:cities, on_delete: :nothing)
      # housing
      add :single_family_homes, {:array, :map}, default: []
      add :multi_family_homes, {:array, :map}, default: []
      add :homeless_shelter, {:array, :map}, default: []
      add :apartments, {:array, :map}, default: []
      add :micro_apartments, {:array, :map}, default: []
      add :high_rises, {:array, :map}, default: []
      # transit
      add :roads, {:array, :map}, default: []
      add :highways, {:array, :map}, default: []
      add :airports, {:array, :map}, default: []
      add :bus_lines, {:array, :map}, default: []
      add :subway_lines, {:array, :map}, default: []
      add :bike_lanes, {:array, :map}, default: []
      add :bikeshare_stations, {:array, :map}, default: []
      # infrastructure
      add :coal_plants, {:array, :map}, default: []
      add :power_plants, {:array, :map}, default: []
      add :wind_turbines, {:array, :map}, default: []
      add :solar_plants, {:array, :map}, default: []
      add :nuclear_plants, {:array, :map}, default: []
      # civic
      add :parks, {:array, :map}, default: []
      add :libraries, {:array, :map}, default: []
      # education
      add :schools, {:array, :map}, default: []
      add :middle_schools, {:array, :map}, default: []
      add :high_schools, {:array, :map}, default: []
      add :universities, {:array, :map}, default: []
      add :research_labs, {:array, :map}, default: []
      # work
      add :factories, {:array, :map}, default: []
      add :retail, {:array, :map}, default: []
      add :office_buildings, {:array, :map}, default: []
      add :retail_shops, {:array, :map}, default: []
      # entertainment
      add :theatres, {:array, :map}, default: []
      add :arenas, {:array, :map}, default: []
      # health
      add :doctor_offices, {:array, :map}, default: []
      add :hospitals, {:array, :map}, default: []

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
