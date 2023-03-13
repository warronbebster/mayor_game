defmodule MayorGame.Repo.Migrations.ConstraintBuildablesToPositive do
  use Ecto.Migration
  require MayorGame.Repo.Migrations.DropDetails

  @buildables_list MayorGame.Repo.Migrations.DropDetails.buildables_list() ++
                     [
                       :megablocks,
                       :natural_gas_plants,
                       :fusion_reactors,
                       :campgrounds,
                       :nature_preserves,
                       :lumber_yards,
                       :fisheries,
                       :uranium_mines,
                       :oil_wells,
                       :lithium_mines,
                       :reservoirs,
                       :salt_farms,
                       :quarries,
                       :distribution_centers,
                       :zoos,
                       :aquariums,
                       :ski_resorts,
                       :resorts,
                       :missile_defense_arrays,
                       :wood_warehouses,
                       :fish_tanks,
                       :lithium_vats,
                       :salt_sheds,
                       :rock_yards,
                       :water_tanks
                     ]
  defmacro buildables_list, do: @buildables_list

  def change do
    for buildable <- @buildables_list do
      create constraint("cities", String.to_atom(to_string(buildable) <> "_must_be_positive"),
               check: "#{to_string(buildable)} >= 0"
             )
    end
  end
end
