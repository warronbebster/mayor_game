defmodule MayorGame.Repo.Migrations.AddBuildables do
  use Ecto.Migration
  # import MayorGame.City.Buildable

  @timestamps_opts [type: :utc_datetime]
  @buildables_list [
    :huts,
    :single_family_homes,
    :multi_family_homes,
    :homeless_shelters,
    :apartments,
    :micro_apartments,
    :high_rises,
    # :megablocks,
    :roads,
    :highways,
    :airports,
    :subway_lines,
    :bus_lines,
    :bike_lanes,
    :bikeshare_stations,
    :coal_plants,
    # :natural_gas_plants,
    :wind_turbines,
    :solar_plants,
    :nuclear_plants,
    :dams,
    # :fusion_reactors,
    :carbon_capture_plants,
    :parks,
    # :campgrounds,
    # :nature_preserves,
    :libraries,
    :schools,
    :middle_schools,
    :high_schools,
    :universities,
    :research_labs,
    # :mines,
    # :lumber_yards,
    # :fisheries,
    # :uranium_mines,
    # :oil_wells,
    # :lithium_mines,
    # :reservoirs,
    # :salt_farms,
    # :quarries,
    # :desalination_plants,
    # :rice_farms,
    # :wheat_farms,
    # :produce_farms,
    # :livestock_farms,
    # :vineyards,
    # :bakeries,
    # :sushi_restaurants,
    # :farmers_markets,
    # :delis,
    # :grocery_stores,
    # :butchers,
    :retail_shops,
    :factories,
    :office_buildings,
    # :distribution_centers,
    :theatres,
    :arenas,
    # :zoos,
    # :aquariums,
    # :ski_resorts,
    # :resorts,
    :hospitals,
    :doctor_offices
    # :air_bases,
    # :defense_bases,
    # :missile_defense_arrays,
    # :wood_warehouses,
    # :fish_tanks,
    # :lithium_vats,
    # :salt_sheds,
    # :rock_yards,
    # :water_tanks,
    # :cow_pens,
    # :silos,
    # :refrigerated_warehouses
  ]
  defmacro buildables_list, do: @buildables_list

  def change do
    for buildable <- @buildables_list do
      create table(buildable) do
        add :enabled, :boolean, default: true
        add :reason, {:array, :string}, default: []
        add :upgrades, {:array, :string}, default: []

        add :details_id, references(:details)

        timestamps()
      end

      create index(buildable, [:details_id])
    end
  end
end
