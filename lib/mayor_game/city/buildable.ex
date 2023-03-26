# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{BuildableMetadata}
  alias MayorGame.Utility
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  @typedoc """
      this makes a type for %Buildable{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  # schemas make elixir structs (in this case, %Buildable{})
  schema "buildable" do
    # has an id built-in?
    # what are the upgrades the buildable currently possesses
    belongs_to(:details, MayorGame.City.Details)

    timestamps()

    @doc false
    def changeset(buildable, attrs \\ %{}) do
      buildable
      |> cast(attrs, [])
    end
  end

  @doc """
  Map of buildables with format %{
    category: %{
      buildable_name: %{
        buildable_detail: int
      }
    }
  }
  """

  def buildables_attack_order do
    [
      :defense_bases,
      :air_bases,
      :missile_defense_arrays
      # :coal_plants,
      # :natural_gas_plants,
      # :wind_turbines,
      # :solar_plants,
      # :nuclear_plants,
      # :fusion_reactors,
      # :dams,
      # :carbon_capture_plants,
      # :roads,
      # :highways,
      # :airports,
      # :bus_lines,
      # :subway_lines,
      # :bike_lanes,
      # :bikeshare_stations,
      # :huts,
      # :single_family_homes,
      # :multi_family_homes,
      # :homeless_shelters,
      # :apartments,
      # :micro_apartments,
      # :high_rises,
      # :megablocks,
      # :hospitals,
      # :doctor_offices,
      # :retail_shops,
      # :factories,
      # :mines,
      # :uranium_mines,
      # :office_buildings,
      # :distribution_centers,
      # :parks,
      # :campgrounds,
      # :nature_preserves,
      # :libraries,
      # :schools,
      # :middle_schools,
      # :high_schools,
      # :universities,
      # :research_labs,
      # :theatres,
      # :arenas,
      # :zoos,
      # :aquariums
    ]
  end

  def buildables_default_priorities do
    %{
      huts: 1,
      single_family_homes: 5,
      multi_family_homes: 5,
      homeless_shelters: 5,
      apartments: 5,
      micro_apartments: 5,
      high_rises: 5,
      megablocks: 5,
      roads: 0,
      highways: 0,
      airports: 6,
      bus_lines: 3,
      subway_lines: 3,
      bike_lanes: 0,
      bikeshare_stations: 0,
      coal_plants: 2,
      natural_gas_plants: 4,
      wind_turbines: 4,
      solar_plants: 4,
      nuclear_plants: 4,
      fusion_reactors: 4,
      dams: 4,
      carbon_capture_plants: 8,
      parks: 9,
      campgrounds: 9,
      nature_preserves: 9,
      libraries: 9,
      schools: 8,
      middle_schools: 8,
      high_schools: 8,
      universities: 8,
      research_labs: 8,
      retail_shops: 9,
      factories: 9,
      mines: 9,
      lithium_mines: 9,
      quarries: 9,
      resorts: 9,
      ski_resorts: 9,
      oil_wells: 9,
      fisheries: 9,
      lumber_yards: 9,
      uranium_mines: 9,
      office_buildings: 9,
      distribution_centers: 9,
      theatres: 9,
      arenas: 9,
      zoos: 9,
      aquariums: 9,
      hospitals: 9,
      doctor_offices: 9,
      air_bases: 7,
      defense_bases: 7,
      missile_defense_arrays: 7,
      wood_warehouses: 9,
      fish_tanks: 9,
      lithium_vats: 9,
      salt_sheds: 9,
      rock_yards: 9,
      water_tanks: 9
    }
  end

  def buildables_kw_list do
    [
      transit: [
        roads: buildables_flat().roads,
        highways: buildables_flat().highways,
        airports: buildables_flat().airports,
        bus_lines: buildables_flat().bus_lines,
        subway_lines: buildables_flat().subway_lines,
        bike_lanes: buildables_flat().bike_lanes,
        bikeshare_stations: buildables_flat().bikeshare_stations
      ],
      housing: [
        huts: buildables_flat().huts,
        single_family_homes: buildables_flat().single_family_homes,
        multi_family_homes: buildables_flat().multi_family_homes,
        homeless_shelters: buildables_flat().homeless_shelters,
        apartments: buildables_flat().apartments,
        micro_apartments: buildables_flat().micro_apartments,
        high_rises: buildables_flat().high_rises,
        megablocks: buildables_flat().megablocks
      ],
      energy: [
        coal_plants: buildables_flat().coal_plants,
        natural_gas_plants: buildables_flat().natural_gas_plants,
        wind_turbines: buildables_flat().wind_turbines,
        solar_plants: buildables_flat().solar_plants,
        nuclear_plants: buildables_flat().nuclear_plants,
        dams: buildables_flat().dams,
        fusion_reactors: buildables_flat().fusion_reactors,
        carbon_capture_plants: buildables_flat().carbon_capture_plants
      ],
      education: [
        schools: buildables_flat().schools,
        middle_schools: buildables_flat().middle_schools,
        high_schools: buildables_flat().high_schools,
        universities: buildables_flat().universities,
        research_labs: buildables_flat().research_labs
      ],
      resources: [
        lumber_yards: buildables_flat().lumber_yards,
        mines: buildables_flat().mines,
        uranium_mines: buildables_flat().uranium_mines,
        salt_farms: buildables_flat().salt_farms,
        lithium_mines: buildables_flat().lithium_mines,
        fisheries: buildables_flat().fisheries,
        quarries: buildables_flat().quarries,
        reservoirs: buildables_flat().reservoirs,
        oil_wells: buildables_flat().oil_wells,
        desalination_plants: buildables_flat().desalination_plants
      ],
      farms: [
        rice_farms: buildables_flat().rice_farms,
        wheat_farms: buildables_flat().wheat_farms,
        produce_farms: buildables_flat().produce_farms,
        livestock_farms: buildables_flat().livestock_farms,
        vineyards: buildables_flat().vineyards
      ],
      food: [
        sushi_restaurants: buildables_flat().sushi_restaurants,
        delis: buildables_flat().delis,
        grocery_stores: buildables_flat().grocery_stores,
        farmers_markets: buildables_flat().farmers_markets,
        butchers: buildables_flat().butchers,
        bakeries: buildables_flat().bakeries
      ],
      civic: [
        parks: buildables_flat().parks,
        campgrounds: buildables_flat().campgrounds,
        nature_preserves: buildables_flat().nature_preserves,
        libraries: buildables_flat().libraries
      ],
      commerce: [
        retail_shops: buildables_flat().retail_shops,
        factories: buildables_flat().factories,
        office_buildings: buildables_flat().office_buildings,
        distribution_centers: buildables_flat().distribution_centers
      ],
      entertainment: [
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas,
        zoos: buildables_flat().zoos,
        aquariums: buildables_flat().aquariums
      ],
      travel: [
        resorts: buildables_flat().resorts,
        ski_resorts: buildables_flat().ski_resorts
      ],
      health: [
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
      ],
      combat: [
        air_bases: buildables_flat().air_bases,
        defense_bases: buildables_flat().defense_bases,
        missile_defense_arrays: buildables_flat().missile_defense_arrays
      ],
      storage: [
        wood_warehouses: buildables_flat().wood_warehouses,
        fish_tanks: buildables_flat().fish_tanks,
        lithium_vats: buildables_flat().lithium_vats,
        salt_sheds: buildables_flat().salt_sheds,
        rock_yards: buildables_flat().rock_yards,
        water_tanks: buildables_flat().water_tanks,
        cow_pens: buildables_flat().cow_pens,
        silos: buildables_flat().silos,
        refrigerated_warehouses: buildables_flat().refrigerated_warehouses
      ]
    ]
  end

  def category_order do
    [
      :transit,
      :housing,
      :energy,
      :education,
      :resources,
      :farms,
      :food,
      :civic,
      :commerce,
      :entertainment,
      :travel,
      :health,
      :combat,
      :storage
    ]
  end

  def buildables do
    category_order = [
      :transit,
      :housing,
      :energy,
      :education,
      :resources,
      :civic,
      :commerce,
      :entertainment,
      :travel,
      :health,
      :combat,
      :storage
    ]

    initial_pass =
      Enum.group_by(Map.values(buildables_flat()), & &1.category)
      |> Enum.map(fn {key, value} -> {key, value} end)

    Enum.reduce(category_order, [], &[{&1, Keyword.fetch!(initial_pass, &1)} | &2])
    |> Enum.reverse()
  end

  def buildables_flat do
    %{
      huts: %BuildableMetadata{
        size: 1,
        category: :housing,
        level: 0,
        title: :huts,
        price: 10,
        requires: %{
          area: 1
        },
        produces: %{
          housing: 1,
          sprawl: 1
        }
      },
      # single family homes ————————————————————————————————————
      single_family_homes: %BuildableMetadata{
        size: 1,
        category: :housing,
        level: 0,
        title: :single_family_homes,
        price: 100,
        requires: %{
          area: 1,
          energy: 12
        },
        produces: %{
          housing: 2,
          pollution: 2,
          sprawl: 5
        }
      },
      # multi family homes ————————————————————————————————————
      multi_family_homes: %BuildableMetadata{
        size: 2,
        category: :housing,
        level: 0,
        title: :multi_family_homes,
        price: 200,
        requires: %{
          area: 1,
          energy: 18
        },
        produces: %{
          housing: 6,
          pollution: 4,
          sprawl: 3
        }
      },
      # homeless shelters ————————————————————————————————————
      homeless_shelters: %BuildableMetadata{
        size: 2,
        category: :housing,
        level: 0,
        title: :homeless_shelters,
        price: 100,
        requires: %{
          area: 5,
          money: 100,
          energy: 70
        },
        produces: %{
          housing: 20
        }
      },
      # apartments ————————————————————————————————————
      apartments: %BuildableMetadata{
        size: 3,
        category: :housing,
        level: 0,
        title: :apartments,
        price: 800,
        requires: %{
          area: 10,
          energy: 90
        },
        produces: %{
          housing: 20,
          pollution: 10
        }
      },
      # micro apartments ————————————————————————————————————
      micro_apartments: %BuildableMetadata{
        size: 2,
        category: :housing,
        level: 0,
        title: :micro_apartments,
        price: 1_300,
        requires: %{
          area: 5,
          energy: 50
        },
        produces: %{
          housing: 20,
          pollution: 5
        }
      },
      # high rises ————————————————————————————————————
      high_rises: %BuildableMetadata{
        size: 5,
        category: :housing,
        level: 0,
        title: :high_rises,
        price: 6_000,
        requires: %{
          area: 2,
          energy: 150
        },
        produces: %{
          housing: 100,
          pollution: 10
        }
      },
      # Megablocks ————————————————————————————————————
      megablocks: %BuildableMetadata{
        size: 10,
        category: :housing,
        level: 0,
        title: :megablocks,
        price: 5_000_000,
        requires: %{
          area: 100,
          energy: 2000
        },
        produces: %{
          housing: 3000,
          pollution: 25
        }
      },
      # TRANSIT ——————————————————————————————————————————————————————————————————————————————
      # roads ————————————————————————————————————
      roads: %BuildableMetadata{
        size: 1,
        category: :transit,
        level: 0,
        title: :roads,
        price: 200,
        produces: %{
          health: -1,
          sprawl: 10,
          area: 25,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.01)
        }
      },
      # highways ————————————————————————————————————
      highways: %BuildableMetadata{
        size: 2,
        category: :transit,
        level: 0,
        title: :highways,
        price: 400,
        multipliers: %{
          region: %{
            health: %{forest: 0.8, mountain: 0.8, desert: 0.9, lake: 0.7}
          }
        },
        produces: %{
          health: -4,
          sprawl: 20,
          area: 50,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.02)
        }
      },
      # Airports —————————————————————————————————————
      airports: %BuildableMetadata{
        size: 3,
        category: :transit,
        level: 0,
        title: :airports,
        price: 2000,
        requires: %{
          workers: %{count: 10, level: 0},
          energy: 150
        },
        produces: %{
          health: -2,
          area: 100,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.03)
        }
      },
      # Subway Lines ————————————————————————————————————
      subway_lines: %BuildableMetadata{
        size: 10,
        category: :transit,
        level: 0,
        title: :subway_lines,
        price: 2000,
        requires: %{
          workers: %{count: 10, level: 0},
          money: 40
        },
        produces: %{
          sprawl: 1,
          area: 1000
        }
      },
      # Bus Lines ————————————————————————————————————
      bus_lines: %BuildableMetadata{
        size: 1,
        category: :transit,
        level: 0,
        title: :bus_lines,
        price: 70,
        requires: %{
          workers: %{count: 10, level: 0},
          money: 30
        },
        produces: %{
          health: -2,
          sprawl: 3,
          area: 50
        }
      },
      # Bike lanes ————————————————————————————————————
      bike_lanes: %BuildableMetadata{
        size: 1,
        category: :transit,
        level: 0,
        title: :bike_lanes,
        price: 60,
        multipliers: %{
          region: %{
            health: %{
              forest: 1.3,
              mountain: 1.4,
              lake: 1.1,
              desert: 1.1,
              ocean: 1.1
            },
            fun: %{
              ocean: 1.5,
              mountain: 0.8,
              desert: 0.6
            }
          }
        },
        produces: %{
          health: 2,
          area: 10
        }
      },
      # Bikeshare Stations ————————————————————————————————————
      bikeshare_stations: %BuildableMetadata{
        size: 1,
        category: :transit,
        level: 0,
        title: :bikeshare_stations,
        price: 70,
        multipliers: %{
          region: %{
            health: %{
              forest: 1.3,
              mountain: 1.4
            },
            fun: %{
              ocean: 1.5,
              mountain: 0.8,
              desert: 0.6
            }
          }
        },
        produces: %{
          health: 1,
          area: 10
        }
      },
      # ENERGY ————————————————————————————————————————————————————————————————————————
      # ENERGY ————————————————————————————————————————————————————————————————————————
      # Coal Plants ————————————————————————————————————
      coal_plants: %BuildableMetadata{
        size: 5,
        category: :energy,
        level: 0,
        title: :coal_plants,
        price: 500,
        multipliers: %{
          region: %{
            energy: %{
              mountain: 1.5
            }
          }
        },
        requires: %{
          area: 5,
          money: 10,
          workers: %{count: 5, level: 0}
        },
        produces: %{
          energy: 2000,
          pollution: 30,
          health: -10
        }
      },
      # Natural Gas Plants ————————————————————————————————————
      natural_gas_plants: %BuildableMetadata{
        size: 1,
        category: :energy,
        level: 1,
        title: :natural_gas_plants,
        price: 800,
        multipliers: %{
          region: %{
            energy: %{
              desert: 1.3
            }
          }
        },
        requires: %{
          area: 15,
          money: 20,
          workers: %{count: 5, level: 1}
        },
        produces: %{
          energy: 2000,
          pollution: 15,
          health: -5
        }
      },
      # wind turbines ————————————————————————————————————
      wind_turbines: %BuildableMetadata{
        size: 1,
        category: :energy,
        level: 1,
        title: :wind_turbines,
        price: 1000,
        multipliers: %{
          region: %{
            energy: %{
              ocean: 1.3,
              desert: 1.5
            }
          },
          season: %{
            energy: %{
              ocean: 1.3,
              desert: 1.5
            }
          }
        },
        requires: %{
          area: 5,
          money: 30,
          workers: %{count: 10, level: 1}
        },
        produces: %{
          energy: 600
        }
      },
      # Solar Plants ————————————————————————————————————
      solar_plants: %BuildableMetadata{
        size: 1,
        category: :energy,
        level: 2,
        title: :solar_plants,
        price: 2000,
        multipliers: %{
          region: %{
            energy: %{
              desert: 1.5,
              ocean: 1.2,
              forest: 0.7
            }
          },
          season: %{
            energy: %{
              spring: 1.2,
              summer: 1.5,
              winter: 0.7
            }
          }
        },
        requires: %{
          money: 10,
          area: 5,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          energy: 500
        }
      },
      # Nuclear Plants ————————————————————————————————————
      nuclear_plants: %BuildableMetadata{
        size: 5,
        category: :energy,
        level: 3,
        title: :nuclear_plants,
        price: 5000,
        requires: %{
          money: 500,
          area: 10,
          workers: %{count: 10, level: 3}
        },
        produces: %{
          energy: 5000
        }
      },
      # Dams ————————————————————————————————————
      dams: %BuildableMetadata{
        size: 4,
        category: :energy,
        level: 2,
        title: :dams,
        price: 5000,
        multipliers: %{
          region: %{
            energy: %{
              mountain: 1.5
            }
          },
          season: %{
            energy: %{
              winter: 0.8,
              spring: 1.3
            }
          }
        },
        requires: %{
          money: 30,
          area: 10,
          workers: %{count: 5, level: 2}
        },
        produces: %{
          energy: 1000,
          water: 10
        }
      },
      # # Fusion Reactors ————————————————————————————————————
      fusion_reactors: %BuildableMetadata{
        size: 5,
        category: :energy,
        level: 4,
        title: :fusion_reactors,
        price: 50_000_000,
        requires: %{
          money: 10_000,
          uranium: 1,
          area: 10,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          energy: 150_000
        }
      },
      # Carbon Capture Plants ————————————————————————————————————
      carbon_capture_plants: %BuildableMetadata{
        size: 5,
        category: :energy,
        level: 5,
        title: :carbon_capture_plants,
        price: 100_000,
        requires: %{
          money: 50,
          area: 10,
          workers: %{count: 10, level: 5}
        },
        produces: %{
          pollution: -100
        }
      },
      # CIVIC ————————————————————————————————————————————————————————————————————————
      # CIVIC ————————————————————————————————————————————————————————————————————————
      # PARKS ————————————————————————————————————
      parks: %BuildableMetadata{
        size: 1,
        category: :civic,
        level: 0,
        title: :parks,
        price: 20,
        multipliers: %{
          region: %{
            health: %{
              ocean: 1.1,
              mountain: 1.4,
              desert: 1.1,
              forest: 1.3,
              lake: 1.1
            },
            fun: %{
              ocean: 1.5,
              mountain: 0.8,
              desert: 1.1,
              forest: 1.2,
              lake: 1.2
            }
          }
        },
        requires: %{
          money: 5,
          area: 10
        },
        produces: %{
          fun: 3,
          health: 5,
          pollution: -1
        }
      },
      # CAMPGROUNDS ————————————————————————————————————
      campgrounds: %BuildableMetadata{
        size: 1,
        category: :civic,
        level: 0,
        title: :campgrounds,
        price: 250,
        multipliers: %{
          region: %{
            health: %{
              ocean: 1.5,
              mountain: 1.4,
              forest: 1.3,
              lake: 1.2
            },
            fun: %{
              ocean: 1.75,
              mountain: 0.9,
              desert: 0.8,
              forest: 1.25,
              lake: 1.4
            }
          }
        },
        requires: %{
          money: 30,
          area: 50,
          workers: %{count: 6, level: 1}
        },
        produces: %{
          fun: 8,
          health: 6,
          pollution: -3
        }
      },
      # NATURE PRESERVES ————————————————————————————————————
      nature_preserves: %BuildableMetadata{
        size: 3,
        category: :civic,
        level: 0,
        title: :nature_preserves,
        price: 2_350,
        multipliers: %{
          region: %{
            health: %{
              ocean: 1.1,
              mountain: 1.4,
              desert: 0.8,
              forest: 1.6,
              lake: 1.2
            },
            fun: %{
              ocean: 1.5,
              mountain: 0.8,
              desert: 0.5,
              forest: 1.5,
              lake: 1.3
            }
          }
        },
        requires: %{
          money: 100,
          area: 100,
          workers: %{count: 6, level: 3}
        },
        produces: %{
          fun: 10,
          health: 5,
          pollution: -12
        }
      },
      # LIBRARIES ————————————————————————————————————
      libraries: %BuildableMetadata{
        size: 1,
        category: :civic,
        level: 2,
        title: :libraries,
        price: 1000,
        requires: %{
          money: 10,
          area: 2,
          energy: 200,
          workers: %{count: 4, level: 2}
        },
        # fn _rng, _number_of_instances -> drop_amount
        produces: %{
          education: fn rng, number_of_buildables ->
            # low-luck calculation at 5% chance, so rng needs only be used once
            Utility.dice_roll(number_of_buildables, 0.05)
          end,
          culture: 1
        }
      },
      # EDUCATION ————————————————————————————————————————————————————————————————————————————————————————————————————————————
      # EDUCATION ————————————————————————————————————————————————————————————————————————————————————————————————————————————
      # SCHOOLS ————————————————————————————————————
      schools: %BuildableMetadata{
        size: 2,
        category: :education,
        level: 0,
        title: :schools,
        price: 2000,
        requires: %{
          money: 10,
          energy: 600,
          area: 5,
          workers: %{count: 10, level: 0}
        },
        produces: %{
          education_lvl_1: 50
        }
      },
      # MIDDLE SCHOOLS ————————————————————————————————————
      middle_schools: %BuildableMetadata{
        size: 3,
        category: :education,
        level: 1,
        title: :middle_schools,
        price: 3000,
        requires: %{
          money: 40,
          energy: 800,
          area: 8,
          workers: %{count: 10, level: 1}
        },
        produces: %{
          education_lvl_2: 30
        }
      },
      # HIGH SCHOOLS ————————————————————————————————————
      high_schools: %BuildableMetadata{
        size: 3,
        category: :education,
        level: 2,
        title: :high_schools,
        price: 4000,
        requires: %{
          money: 70,
          energy: 800,
          area: 10,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          education_lvl_3: 20
        }
      },
      # UNIVERSITIES ————————————————————————————————————
      universities: %BuildableMetadata{
        size: 4,
        category: :education,
        level: 3,
        title: :universities,
        price: 6500,
        requires: %{
          money: 150,
          energy: 1200,
          area: 20,
          workers: %{count: 10, level: 3}
        },
        produces: %{
          education_lvl_4: 10
        }
      },
      # RESEARCH LABS ————————————————————————————————————
      research_labs: %BuildableMetadata{
        size: 2,
        category: :education,
        level: 4,
        title: :research_labs,
        price: 9000,
        requires: %{
          money: 200,
          energy: 800,
          area: 30,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          education_lvl_5: 5
        }
      },
      # Resources ————————————————————————————————————————————————————————————————————————————
      # Resources ————————————————————————————————————————————————————————————————————————————
      # MINES ————————————————————————————————————
      mines: %BuildableMetadata{
        size: 5,
        category: :resources,
        level: 0,
        title: :mines,
        price: 5000,
        requires: %{
          money: 250,
          energy: 1900,
          area: 25,
          workers: %{count: 30, level: 0}
        },
        produces: %{
          health: -5,
          pollution: 10,
          sulfur: 1,
          # fn _rng, _number_of_instances -> drop_amount
          uranium: fn rng, number_of_buildables ->
            # low-luck calculation at 0.1% chance, so rng needs only be used once
            Utility.dice_roll(number_of_buildables, 0.001)
          end
          # gold: 1,
        },
        stores: %{sulfur: 1000}
      },
      # LUMBER YARDS ————————————————————————————————————
      lumber_yards: %BuildableMetadata{
        regions: [:mountain, :forest],
        size: 5,
        category: :resources,
        level: 0,
        title: :lumber_yards,
        price: 100_000,
        requires: %{
          money: 250,
          energy: 1900,
          area: 25,
          workers: %{count: 10, level: 1}
        },
        produces: %{wood: 5},
        stores: %{wood: 500}
      },
      # FISHERIES ————————————————————————————————————
      fisheries: %BuildableMetadata{
        regions: [:lake, :ocean],
        size: 5,
        category: :resources,
        level: 0,
        title: :fisheries,
        price: 50_000,
        requires: %{
          money: 250,
          energy: 100,
          area: 5,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          fish: 5
        },
        stores: %{fish: 100}
      },
      # URANIUM MINES ————————————————————————————————————
      uranium_mines: %BuildableMetadata{
        size: 3,
        category: :resources,
        level: 4,
        title: :uranium_mines,
        price: 20_000_000,
        requires: %{
          money: 1000,
          energy: 5000,
          area: 100,
          workers: %{count: 20, level: 4}
        },
        produces: %{
          health: -50,
          pollution: 50,
          uranium: 1
        },
        stores: %{uranium: 1000}
      },
      # OIL WELLS ————————————————————————————————————
      oil_wells: %BuildableMetadata{
        regions: [:desert],
        size: 3,
        category: :resources,
        level: 4,
        title: :oil_wells,
        price: 10_000_000,
        requires: %{
          money: 1000,
          energy: 3000,
          area: 100,
          workers: %{count: 20, level: 1}
        },
        produces: %{
          health: -50,
          pollution: 50,
          oil: 1
        },
        stores: %{oil: 1000}
      },
      # LITHIUM MINES ————————————————————————————————————
      lithium_mines: %BuildableMetadata{
        regions: [:desert],
        size: 3,
        category: :resources,
        level: 4,
        title: :lithium_mines,
        price: 30_000_000,
        requires: %{
          money: 1000,
          energy: 5000,
          area: 100,
          workers: %{count: 20, level: 4}
        },
        produces: %{
          health: -50,
          pollution: 50,
          lithium: 1
        },
        stores: %{lithium: 100}
      },
      # RESERVOIRS ————————————————————————————————————
      reservoirs: %BuildableMetadata{
        regions: [:lake, :mountain],
        size: 10,
        category: :resources,
        level: 4,
        title: :reservoirs,
        price: 3_000_000,
        requires: %{
          money: 100,
          energy: 100,
          area: 500,
          workers: %{count: 5, level: 1}
        },
        produces: %{
          water: 100
        },
        stores: %{water: 1000}
      },
      # SALT FARMS ————————————————————————————————————
      salt_farms: %BuildableMetadata{
        regions: [:ocean],
        size: 5,
        category: :resources,
        level: 4,
        title: :salt_farms,
        price: 2_000_000,
        requires: %{
          money: 1000,
          energy: 500,
          area: 250,
          workers: %{count: 10, level: 2}
        },
        produces: %{salt: 1},
        stores: %{salt: 100}
      },
      # QUARRIES ————————————————————————————————————
      quarries: %BuildableMetadata{
        regions: [:mountain],
        size: 5,
        category: :resources,
        level: 4,
        title: :quarries,
        price: 2_000_000,
        requires: %{
          money: 1000,
          energy: 500,
          area: 100,
          workers: %{count: 20, level: 4}
        },
        produces: %{stone: 1},
        stores: %{stone: 100}
      },
      # DESALINATION PLANTS
      desalination_plants: %BuildableMetadata{
        regions: [:ocean],
        size: 5,
        category: :resources,
        level: 4,
        title: :desalination_plants,
        price: 2_000_000,
        requires: %{
          money: 1000,
          energy: 1000,
          area: 100,
          workers: %{count: 8, level: 4}
        },
        produces: %{water: 1, salt: 1},
        stores: %{water: 50, salt: 50}
      },
      # FARMS ————————————————————————————————————————————————————————————————————————————————
      # FARMS ————————————————————————————————————————————————————————————————————————————————
      # RICE FARMS
      rice_farms: %BuildableMetadata{
        regions: [:mountain],
        size: 5,
        category: :farms,
        level: 4,
        title: :rice_farms,
        price: 1_000_000,
        requires: %{
          money: 10,
          water: 20,
          energy: 10,
          area: 100,
          workers: %{count: 5, level: 0}
        },
        produces: %{rice: 1},
        stores: %{rice: 50}
      },
      # WHEAT FARMS
      wheat_farms: %BuildableMetadata{
        regions: [:forest, :lake],
        size: 5,
        category: :farms,
        level: 4,
        title: :wheat_farms,
        price: 1_000_000,
        requires: %{
          money: 10,
          water: 5,
          energy: 10,
          area: 100,
          workers: %{count: 5, level: 0}
        },
        produces: %{wheat: 1},
        stores: %{wheat: 50}
      },
      # PRODUCE FARMS
      produce_farms: %BuildableMetadata{
        size: 5,
        category: :farms,
        level: 4,
        title: :produce_farms,
        price: 1_000_000,
        requires: %{
          money: 10,
          water: 5,
          energy: 10,
          area: 100,
          workers: %{count: 5, level: 0}
        },
        produces: %{produce: 1},
        stores: %{produce: 50}
      },
      # LIVESTOCK FARMS
      livestock_farms: %BuildableMetadata{
        size: 5,
        category: :farms,
        level: 4,
        title: :livestock_farms,
        price: 1_000_000,
        requires: %{
          money: 10,
          water: 10,
          energy: 10,
          area: 100,
          workers: %{count: 5, level: 0}
        },
        produces: %{cows: 1},
        stores: %{cows: 50}
      },
      # Vineyards
      vineyards: %BuildableMetadata{
        regions: [:mountain, :desert, :forest],
        size: 5,
        category: :farms,
        level: 4,
        title: :vineyards,
        price: 1_000_000,
        requires: %{
          money: 10,
          water: 10,
          energy: 10,
          area: 100,
          workers: %{count: 5, level: 0}
        },
        produces: %{grapes: 1},
        stores: %{grapes: 50}
      },
      # FOOD ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
      # FOOD ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
      # BAKERIES
      bakeries: %BuildableMetadata{
        size: 2,
        category: :food,
        level: 4,
        title: :bakeries,
        price: 400_000,
        requires: %{
          money: 10,
          wheat: 5,
          salt: 1,
          water: 5,
          energy: 10,
          area: 5,
          workers: %{count: 5, level: 1}
        },
        produces: %{bread: 1},
        stores: %{bread: 50}
      },
      # SUSHI RESTAURANTS
      sushi_restaurants: %BuildableMetadata{
        size: 2,
        category: :food,
        level: 4,
        title: :sushi_restaurants,
        price: 7_000,
        requires: %{
          money: 10,
          water: 1,
          rice: 5,
          fish: 5,
          energy: 50,
          area: 2,
          workers: %{count: 5, level: 3}
        },
        produces: %{food: 10, culture: 1},
        stores: %{food: 25}
      },
      # FARMERS MARKETS
      farmers_markets: %BuildableMetadata{
        size: 2,
        category: :food,
        level: 4,
        title: :farmers_markets,
        price: 2000,
        requires: %{
          produce: 5,
          area: 5,
          workers: %{count: 5, level: 2}
        },
        produces: %{food: 50, health: 5},
        stores: %{food: 50}
      },
      # DELIS
      delis: %BuildableMetadata{
        size: 2,
        category: :food,
        level: 4,
        title: :delis,
        price: 2000,
        requires: %{
          money: 10,
          bread: 1,
          meat: 1,
          energy: 10,
          area: 2,
          workers: %{count: 5, level: 1}
        },
        produces: %{food: 25},
        stores: %{food: 50}
      },
      # GROCERY STORES
      grocery_stores: %BuildableMetadata{
        size: 2,
        category: :food,
        level: 4,
        title: :grocery_stores,
        price: 40000,
        requires: %{
          money: 10,
          bread: 5,
          water: 1,
          rice: 5,
          meat: 1,
          produce: 1,
          area: 5,
          energy: 10,
          workers: %{count: 15, level: 1}
        },
        produces: %{food: 100},
        stores: %{food: 1000}
      },
      # BUTCHERS
      butchers: %BuildableMetadata{
        size: 2,
        category: :food,
        level: 4,
        title: :butchers,
        price: 5000,
        requires: %{
          cows: 1,
          area: 2,
          energy: 5,
          workers: %{count: 2, level: 2}
        },
        produces: %{meat: 10},
        stores: %{meat: 50}
      },
      # BUSINESS ——————————————————————————————————————————————————————————————————————————————————————————————————————————
      # BUSINESS ——————————————————————————————————————————————————————————————————————————————————————————————————————————
      # RETAIL SHOPS ————————————————————————————————————
      retail_shops: %BuildableMetadata{
        size: 1,
        category: :commerce,
        level: 5,
        title: :retail_shops,
        price: 1000,
        requires: %{
          money: 2,
          energy: 100,
          area: 2,
          workers: %{count: 3, level: 0}
        }
      },
      # FACTORIES ————————————————————————————————————
      factories: %BuildableMetadata{
        size: 7,
        category: :commerce,
        level: 0,
        title: :factories,
        price: 50000,
        requires: %{
          money: 50,
          energy: 1900,
          area: 15,
          workers: %{count: 20, level: 0}
        },
        produces: %{
          health: -3,
          pollution: 1,
          steel: 10
        },
        stores: %{
          steel: 1000
        }
      },
      # OFFICE BUILDINGS ————————————————————————————————————
      office_buildings: %BuildableMetadata{
        size: 3,
        category: :commerce,
        level: 1,
        title: :office_buildings,
        price: 8000,
        requires: %{
          money: 5,
          energy: 800,
          area: 2,
          workers: %{count: 20, level: 1}
        }
      },
      # DISTRIBUTION CENTERS ————————————————————————————————
      distribution_centers: %BuildableMetadata{
        size: 8,
        category: :commerce,
        level: 0,
        title: :distribution_centers,
        price: 100_000,
        requires: %{
          money: 25,
          energy: 1500,
          area: 100,
          workers: %{count: 250, level: 0}
        },
        produces: %{
          health: -3,
          fun: -10,
          pollution: 1
        }
      },
      # Entertainment ——————————————————————————————————————————————
      # ————————————————————————————————————————————————————————————
      # THEATRES ————————————————————————————————————
      theatres: %BuildableMetadata{
        size: 2,
        category: :entertainment,
        level: 0,
        title: :theatres,
        price: 3000,
        requires: %{
          money: 10,
          energy: 300,
          area: 5,
          workers: %{count: 10, level: 0}
        },
        produces: %{
          fun: 5,
          culture: 1
        }
      },
      # ARENAS ————————————————————————————————————
      arenas: %BuildableMetadata{
        size: 5,
        category: :entertainment,
        level: 0,
        title: :arenas,
        price: 5_000,
        requires: %{
          money: 100,
          energy: 500,
          area: 40,
          workers: %{count: 20, level: 0}
        },
        produces: %{
          fun: 10
        }
      },
      # ZOOS ————————————————————————————————————
      zoos: %BuildableMetadata{
        size: 3,
        category: :entertainment,
        level: 0,
        title: :zoos,
        price: 2_500,
        multipliers: %{
          region: %{
            energy: %{
              desert: 1.2
            },
            money: %{
              desert: 1.2,
              mountain: 1.3
            }
          },
          season: %{
            energy: %{
              winter: 1.2,
              summer: 1.2
            }
          }
        },
        requires: %{
          money: 250,
          energy: 250,
          area: 70,
          workers: %{count: 10, level: 3}
        },
        produces: %{
          fun: 9,
          pollution: -1
        }
      },
      # AQUARIUMS ————————————————————————————————————
      aquariums: %BuildableMetadata{
        size: 3,
        category: :entertainment,
        level: 0,
        title: :aquariums,
        price: 7_500,
        multipliers: %{
          region: %{
            energy: %{
              desert: 1.2,
              ocean: 0.9,
              lake: 0.9
            },
            money: %{
              ocean: 0.75,
              lake: 0.75
            }
          },
          season: %{
            energy: %{
              winter: 1.25,
              summer: 1.25
            }
          }
        },
        requires: %{
          money: 380,
          energy: 450,
          area: 60,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          fun: 20,
          pollution: -1
        }
      },
      # Travel ——————————————————————————————————————————————
      # ————————————————————————————————————————————————————————————
      # SKI_RESORTS ————————————————————————————————————
      ski_resorts: %BuildableMetadata{
        regions: [:mountain],
        size: 3,
        category: :travel,
        level: 2,
        title: :ski_resorts,
        price: 200_000,
        requires: %{
          money: 1000,
          energy: 400,
          area: 50,
          workers: %{count: 25, level: 2}
        },
        produces: %{
          health: 10,
          fun: 50
        }
      },
      # ————————————————————————————————————————————————————————————
      # RESORTS ————————————————————————————————————
      resorts: %BuildableMetadata{
        regions: [:ocean],
        size: 3,
        category: :travel,
        level: 2,
        title: :resorts,
        price: 100_000,
        requires: %{
          money: 500,
          energy: 200,
          area: 30,
          workers: %{count: 5, level: 2}
        },
        produces: %{
          health: 10,
          fun: 50
        }
      },

      # Health ——————————————————————————————————————————————
      # ————————————————————————————————————————————————————————————
      # HOSPITALS ————————————————————————————————————
      hospitals: %BuildableMetadata{
        size: 6,
        category: :health,
        level: 2,
        title: :hospitals,
        price: 12_000,
        requires: %{
          money: 100,
          energy: 400,
          area: 20,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          health: 10
        }
      },
      # DOCTOR OFFICES ————————————————————————————————————
      doctor_offices: %BuildableMetadata{
        size: 3,
        category: :health,
        level: 4,
        title: :doctor_offices,
        price: 6000,
        requires: %{
          money: 50,
          energy: 50,
          area: 4,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          health: 15
        }
      },
      # COMBAT —————————————————————————————————————————————————————————————————————
      # COMBAT —————————————————————————————————————————————————————————————————————
      # AIR BASES ————————————————————————————————————
      air_bases: %BuildableMetadata{
        size: 2,
        category: :combat,
        level: 5,
        title: :air_bases,
        price: 100_000_000,
        building_reqs: %{steel: 500},
        requires: %{
          money: 5000,
          steel: 50,
          sulfur: 5,
          energy: 5000,
          area: 500,
          workers: %{count: 10, level: 5}
        },
        produces: %{
          missiles: 1,
          daily_strikes: 1
        },
        stores: %{
          missiles: 100
        }
      },
      # DEFENSE BASES ————————————————————————————————————
      defense_bases: %BuildableMetadata{
        size: 1,
        category: :combat,
        level: 2,
        title: :defense_bases,
        price: 50_000_000,
        building_reqs: %{steel: 500},
        requires: %{
          money: 2000,
          energy: 2500,
          area: 100,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          shields: 1
        },
        stores: %{
          shields: 100
        }
      },
      # MISSILE DEFENSE ARRAY ————————————————————————————————————
      missile_defense_arrays: %BuildableMetadata{
        size: 1,
        category: :combat,
        level: 2,
        title: :missile_defense_arrays,
        price: 20_000_000,
        building_reqs: %{steel: 300},
        requires: %{
          money: 5000,
          steel: 100,
          sulfur: 20,
          energy: 10000,
          area: 2000,
          workers: %{count: 20, level: 5}
        },
        stores: %{
          shields: 200
        }
      },
      # STORAGE ——————————————————————————————————————————————————
      # STORAGE ——————————————————————————————————————————————————
      # Wood_warehouses
      wood_warehouses: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :wood_warehouses,
        price: 5000,
        building_reqs: %{steel: 100},
        requires: %{area: 10},
        stores: %{wood: 100}
      },
      fish_tanks: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :fish_tanks,
        price: 5000,
        building_reqs: %{steel: 100, water: 100},
        requires: %{area: 5},
        stores: %{fish: 1000}
      },
      lithium_vats: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :lithium_vats,
        price: 10_000,
        building_reqs: %{steel: 100},
        requires: %{area: 5},
        stores: %{lithium: 1000}
      },
      salt_sheds: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :salt_sheds,
        price: 5000,
        building_reqs: %{steel: 100},
        requires: %{area: 10},
        stores: %{salt: 100}
      },
      rock_yards: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :rock_yards,
        price: 5000,
        building_reqs: %{steel: 100},
        requires: %{area: 20},
        stores: %{stone: 100}
      },
      water_tanks: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :water_tanks,
        price: 5000,
        building_reqs: %{steel: 100},
        requires: %{area: 10},
        stores: %{water: 100}
      },
      cow_pens: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :cow_pens,
        price: 50000,
        building_reqs: %{steel: 100},
        requires: %{area: 10},
        stores: %{cows: 100}
      },
      silos: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :silos,
        price: 50000,
        building_reqs: %{steel: 100},
        requires: %{area: 10},
        stores: %{rice: 100, wheat: 100}
      },
      refrigerated_warehouses: %BuildableMetadata{
        size: 5,
        category: :storage,
        level: 2,
        title: :refrigerated_warehouses,
        price: 80000,
        building_reqs: %{steel: 100},
        requires: %{area: 10, energy: 10, workers: %{count: 5, level: 0}},
        stores: %{bread: 500, grapes: 500, produce: 500, meat: 500}
      }
    }
  end

  @doc """
  generates and returns a list [] of buildables in atom form
  """
  def buildables_list do
    Enum.reduce(buildables_flat(), [], fn {building_type, _building_options}, acc2 ->
      [building_type | acc2]
    end)
  end

  @doc """
  an ordered list of buildabels to build generatives every day
  """
  def buildables_ordered do
    needs_nothing =
      Map.filter(buildables_flat(), fn {_cat, stats} -> stats.requires == nil end)
      |> Map.keys()

    # ^ airports
    rest_of_them =
      get_requirements_keys([:energy, :money, :commerceers]) ++
        get_requirements_keys([:energy, :area]) ++
        get_requirements_keys([:energy, :commerceers]) ++
        get_requirements_keys([:money, :area]) ++
        get_requirements_keys([:energy, :area, :money]) ++
        get_requirements_keys([:energy, :area, :commerceers]) ++
        get_requirements_keys([:energy, :area, :money, :commerceers]) ++
        get_requirements_keys([:energy, :area, :money, :commerceers, :steel, :sulfur])

    [
      needs_nothing,
      get_requirements_keys([:area]),
      get_requirements_keys([:money]),
      get_requirements_keys([:area, :commerceers]),
      # this is basically all energy gen
      # ^ bus lines and subways
      get_requirements_keys([:area, :money, :commerceers]) ++
        get_requirements_keys([:money, :commerceers]),
      # this is basically all energy gen

      get_requirements_keys([:money, :energy]),
      Enum.sort_by(rest_of_them, &buildables_flat()[&1].level, :desc)

      # get_requirements_keys([:energy, :money, :commerceers]),
      # get_requirements_keys([:energy, :area]),
      # get_requirements_keys([:energy, :commerceers]),
      # # parks
      # get_requirements_keys([:money, :area]),
      # get_requirements_keys([:energy, :area, :money]),
      # get_requirements_keys([:energy, :area, :commerceers]),
      # get_requirements_keys([:energy, :area, :money, :commerceers]),
      # get_requirements_keys([:energy, :area, :money, :commerceers, :steel, :sulfur])
    ]
  end

  @doc """
  a flat list of buildable atoms in order of generation
  """
  def buildables_ordered_flat do
    List.flatten(buildables_ordered())
  end

  defp check_requirements(requirements_map, list_of_reqs) do
    requirements_map != nil and Enum.sort(Map.keys(requirements_map)) == Enum.sort(list_of_reqs)
  end

  defp get_requirements_keys(list_of_reqs) do
    # results =
    Map.filter(buildables_flat(), fn {_cat, stats} ->
      check_requirements(stats.requires, list_of_reqs)
    end)
    |> Map.keys()
    |> Enum.sort_by(&buildables_flat()[&1].level, :desc)
  end

  # def sorted_buildables do
  #   Enum.filter(buildables_flat(), fn {_name, metadata} ->
  #     nil
  #   end)
  # end

  def empty_buildable_map do
    Map.new(buildables_list(), fn x -> {x, []} end)
  end

  # ——————————————————————————————————————————————————————————————————

  # defmodule MayorGame.City.Upgrade do
  #   use Ecto.Schema

  #   embedded_schema do
  #     field :cost, :integer
  #     field :active, :boolean
  #     field :requirements, {:array, :string}
  #   end
  # end
end
