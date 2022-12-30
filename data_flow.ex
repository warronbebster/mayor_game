
the Details struct for a town contains a list of %Buildable{} structs for each buildable type atom
e.g.
single_family_homes: [%Buildable{}, %Buildable{} ]

This comes from the DB, as part of a %Buildable{}:
{
  __meta__: Ecto.Schema.Metadata.t(),
  id: integer | nil,
  enabled: boolean,
  reason: list,
  details: map,
  upgrades: ["upgradeName"],
  inserted_at: DateTime.t() | nil,
  updated_at: DateTime.t() | nil
}

# But then this metadata comes from buildables() in the Buildables module:

single_family_homes: %{
  price: 20,
  fits: 2,
  money_required: 0,
  area_required: 1,
  energy_required: 12,
  purchasable: true,
  upgrades: %{
    upgrade_1: %{
      cost: 5,
      description: "+1 fit",
      requirements: [],
      function: %{fits: &(&1 + 1)}
    },
    upgrade_2: %{
      cost: 10,
      description: "-5 Energy required ",
      requirements: [:upgrade_1],
      function: %{energy_required: &(&1 - 5)}
    }
  },
  purchasable_reason: "valid"
},

in the calculate functions, building_options are the above map associated with the buildable type
so the goal is to transform the building_options map for each %Buildable{}

pseudocode:

for each %Buildable{} in Details.name_of_buildable (this probably doesn't need to be part of the func)

# check if there are upgrades

# if so, for each upgrade, grab the upgrade from the %BuildingMetadata
# and apply the :function from the upgrade onto the %BuildingMetadata

# return the %BuildingMetadata

two places this needs to be done — one in city_helpers, and one in city_live to display to user
