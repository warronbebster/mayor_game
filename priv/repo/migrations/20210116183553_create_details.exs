defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration


  def change do
    create table(:details) do
      add :city_treasury, :integer, default: 500
      add :info_id, references(:cities, on_delete: :nothing)
      # housing
      # add :single_family_homes, :map
      # add :multi_family_homes, :map
      # add :homeless_shelter, :map
      # add :apartments, :map
      # add :micro_apartments, :map
      # add :high_rises, :map
      # # transit
      # add :roads, :map
      # add :highways, :map
      # add :airports, :map
      # add :bus_lines, :map
      # add :subway_lines, :map
      # add :bike_lanes, :map
      # add :bikeshare_stations, :map
      # # infrastructure
      # add :coal_plants, :map
      # add :power_plants, :map
      # add :wind_turbines, :map
      # add :solar_plants, :map
      # add :nuclear_plants, :map
      # # civic
      # add :parks, :map
      # add :libraries, :map
      # # education
      # add :schools, :map
      # add :middle_schools, :map
      # add :high_schools, :map
      # add :universities, :map
      # add :research_labs, :map
      # # work
      # add :factories, :map
      # add :retail, :map
      # add :office_buildings, :map
      # add :retail_shops, :map
      # # entertainment
      # add :theatres, :map
      # add :arenas, :map
      # # health
      # add :doctor_offices, :map
      # add :hospitals, :map

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
