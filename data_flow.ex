
Details for a town contains a list of %Buildable{} structs
[%Buildable{} ]

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

This comes from buildables() in the Buildables module:

single_family_homes: %{
  price: 20,
  fits: 2,
  daily_cost: 0,
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
