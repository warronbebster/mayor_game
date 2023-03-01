# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{BuildableMetadata}
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
  def buildables do
    %{
      housing: %{
        huts: buildables_flat().huts,
        single_family_homes: buildables_flat().single_family_homes,
        multi_family_homes: buildables_flat().multi_family_homes,
        homeless_shelters: buildables_flat().homeless_shelters,
        apartments: buildables_flat().apartments,
        micro_apartments: buildables_flat().micro_apartments,
        high_rises: buildables_flat().high_rises,
        megablocks: buildables_flat().megablocks
      },
      transit: %{
        roads: buildables_flat().roads,
        highways: buildables_flat().highways,
        airports: buildables_flat().airports,
        bus_lines: buildables_flat().bus_lines,
        subway_lines: buildables_flat().subway_lines,
        bike_lanes: buildables_flat().bike_lanes,
        bikeshare_stations: buildables_flat().bikeshare_stations
      },
      energy: [
        coal_plants: buildables_flat().coal_plants,
        natural_gas_plants: buildables_flat().natural_gas_plants,
        wind_turbines: buildables_flat().wind_turbines,
        solar_plants: buildables_flat().solar_plants,
        nuclear_plants: buildables_flat().nuclear_plants,
        fusion_reactors: buildables_flat().fusion_reactors,
        dams: buildables_flat().dams,
        carbon_capture_plants: buildables_flat().carbon_capture_plants
      ],
      civic: %{
        parks: buildables_flat().parks,
        campgrounds: buildables_flat().campgrounds,
        nature_preserves: buildables_flat().nature_preserves,
        libraries: buildables_flat().libraries
      },
      education: %{
        schools: buildables_flat().schools,
        middle_schools: buildables_flat().middle_schools,
        high_schools: buildables_flat().high_schools,
        universities: buildables_flat().universities,
        research_labs: buildables_flat().research_labs
      },
      work: %{
        retail_shops: buildables_flat().retail_shops,
        factories: buildables_flat().factories,
        mines: buildables_flat().mines,
        uranium_mines: buildables_flat().uranium_mines,
        office_buildings: buildables_flat().office_buildings,
        distribution_centers: buildables_flat().distribution_centers
      },
      entertainment: %{
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas,
        zoos: buildables_flat().zoos,
        aquariums: buildables_flat().aquariums
      },
      health: %{
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
      },
      combat: %{
        air_bases: buildables_flat().air_bases,
        defense_bases: buildables_flat().defense_bases,
        missile_defense_arrays: buildables_flat().missile_defense_arrays
      }
    }
  end

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
      missile_defense_arrays: 7
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
      civic: [
        parks: buildables_flat().parks,
        campgrounds: buildables_flat().campgrounds,
        nature_preserves: buildables_flat().nature_preserves,
        libraries: buildables_flat().libraries
      ],
      work: [
        retail_shops: buildables_flat().retail_shops,
        factories: buildables_flat().factories,
        mines: buildables_flat().mines,
        uranium_mines: buildables_flat().uranium_mines,
        office_buildings: buildables_flat().office_buildings,
        distribution_centers: buildables_flat().distribution_centers
      ],
      entertainment: [
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas,
        zoos: buildables_flat().zoos,
        aquariums: buildables_flat().aquariums
      ],
      health: [
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
      ],
      combat: [
        air_bases: buildables_flat().air_bases,
        defense_bases: buildables_flat().defense_bases,
        missile_defense_arrays: buildables_flat().missile_defense_arrays
      ]
    ]
  end

  def buildables_flat do
    %{
      huts: %BuildableMetadata{
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
          sprawl: 5
        }
      },
      # multi family homes ————————————————————————————————————
      multi_family_homes: %BuildableMetadata{
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
          sprawl: 3
        }
      },
      # homeless shelters ————————————————————————————————————
      homeless_shelters: %BuildableMetadata{
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
        category: :housing,
        level: 0,
        title: :apartments,
        price: 800,
        requires: %{
          area: 10,
          energy: 90
        },
        produces: %{
          housing: 20
        }
      },
      # micro apartments ————————————————————————————————————
      micro_apartments: %BuildableMetadata{
        category: :housing,
        level: 0,
        title: :micro_apartments,
        price: 1_300,
        requires: %{
          area: 5,
          energy: 50
        },
        produces: %{
          housing: 20
        }
      },
      # high rises ————————————————————————————————————
      high_rises: %BuildableMetadata{
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
          pollution: 50
        }
      },
      # roads ————————————————————————————————————
      roads: %BuildableMetadata{
        category: :transit,
        level: 0,
        title: :roads,
        price: 200,
        produces: %{
          health: -1,
          sprawl: 10,
          area: 10,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.01)
        }
      },
      # highways ————————————————————————————————————
      highways: %BuildableMetadata{
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
          area: 20,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.02)
        }
      },
      # Airports —————————————————————————————————————
      airports: %BuildableMetadata{
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
          area: 10,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.03)
        }
      },
      # Subway Lines ————————————————————————————————————
      subway_lines: %BuildableMetadata{
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
      # Coal Plants ————————————————————————————————————
      coal_plants: %BuildableMetadata{
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
          energy: 1000
        }
      },
      # # Fusion Reactors ————————————————————————————————————
      fusion_reactors: %BuildableMetadata{
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
      # PARKS ————————————————————————————————————
      parks: %BuildableMetadata{
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
              desert: 1.1,
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
        # todo: make random
        produces: %{
          education: fn level, num -> %{level => num} end
        }
      },
      # SCHOOLS ————————————————————————————————————
      schools: %BuildableMetadata{
        category: :education,
        level: 0,
        title: :schools,
        price: 2000,
        education_level: 1,
        capacity: 10,
        requires: %{
          money: 10,
          energy: 600,
          area: 5,
          workers: %{count: 10, level: 0}
        },
        produces: %{
          education: %{1 => 10}
        }
      },
      # MIDDLE SCHOOLS ————————————————————————————————————
      middle_schools: %BuildableMetadata{
        category: :education,
        level: 1,
        title: :middle_schools,
        price: 3000,
        education_level: 2,
        capacity: 10,
        requires: %{
          money: 40,
          energy: 800,
          area: 8,
          workers: %{count: 10, level: 1}
        },
        produces: %{
          education: %{2 => 10}
        }
      },
      # HIGH SCHOOLS ————————————————————————————————————
      high_schools: %BuildableMetadata{
        category: :education,
        level: 2,
        title: :high_schools,
        price: 4000,
        education_level: 3,
        capacity: 10,
        requires: %{
          money: 70,
          energy: 800,
          area: 10,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          education: %{3 => 10}
        }
      },
      # UNIVERSITIES ————————————————————————————————————
      universities: %BuildableMetadata{
        category: :education,
        level: 3,
        title: :universities,
        price: 6500,
        education_level: 4,
        capacity: 10,
        requires: %{
          money: 150,
          energy: 1200,
          area: 20,
          workers: %{count: 10, level: 3}
        },
        produces: %{
          education: %{4 => 10}
        }
      },
      # RESEARCH LABS ————————————————————————————————————
      research_labs: %BuildableMetadata{
        category: :education,
        level: 4,
        title: :research_labs,
        price: 9000,
        education_level: 5,
        capacity: 5,
        requires: %{
          money: 200,
          energy: 1200,
          area: 30,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          education: %{5 => 10}
        }
      },
      # RETAIL SHOPS ————————————————————————————————————
      retail_shops: %BuildableMetadata{
        category: :work,
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
        category: :work,
        level: 0,
        title: :factories,
        price: 5000,
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
        }
      },
      # MINES ————————————————————————————————————
      mines: %BuildableMetadata{
        category: :work,
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
          uranium: fn result -> if result, do: 1, else: 0 end
          # gold: 1,
        }
      },
      # URANIUM MINES ————————————————————————————————————
      uranium_mines: %BuildableMetadata{
        category: :work,
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
          # sulfur: 1
          uranium: 1
          # gold: 1,
        }
      },
      # OFFICE BUILDINGS ————————————————————————————————————
      office_buildings: %BuildableMetadata{
        category: :work,
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
        category: :work,
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
      # THEATRES ————————————————————————————————————
      theatres: %BuildableMetadata{
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
          fun: 5
        }
      },
      # ARENAS ————————————————————————————————————
      arenas: %BuildableMetadata{
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
      # HOSPITALS ————————————————————————————————————
      hospitals: %BuildableMetadata{
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
      # AIR BASES ————————————————————————————————————
      air_bases: %BuildableMetadata{
        category: :combat,
        level: 5,
        title: :air_bases,
        price: 100_000_000,
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
          missiles_capacity: 100,
          daily_strikes: 1
        }
      },
      # DEFENSE BASES ————————————————————————————————————
      defense_bases: %BuildableMetadata{
        category: :combat,
        level: 2,
        title: :defense_bases,
        price: 50_000_000,
        requires: %{
          money: 2000,
          energy: 2500,
          area: 100,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          shields: 1,
          shields_capacity: 100
        }
      },
      # MISSILE DEFENSE ARRAY ————————————————————————————————————
      missile_defense_arrays: %BuildableMetadata{
        category: :combat,
        level: 2,
        title: :missile_defense_arrays,
        price: 20_000_000,
        requires: %{
          money: 50000,
          steel: 100,
          sulfur: 20,
          energy: 10000,
          area: 2000,
          workers: %{count: 20, level: 5}
        },
        produces: %{
          shields_capacity: 200
        }
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
      get_requirements_keys([:energy, :money, :workers]) ++
        get_requirements_keys([:energy, :area]) ++
        get_requirements_keys([:energy, :workers]) ++
        get_requirements_keys([:money, :area]) ++
        get_requirements_keys([:energy, :area, :money]) ++
        get_requirements_keys([:energy, :area, :workers]) ++
        get_requirements_keys([:energy, :area, :money, :workers]) ++
        get_requirements_keys([:energy, :area, :money, :workers, :steel, :sulfur])

    [
      needs_nothing,
      get_requirements_keys([:area]),
      get_requirements_keys([:money]),
      get_requirements_keys([:area, :workers]),
      # this is basically all energy gen
      # ^ bus lines and subways
      get_requirements_keys([:area, :money, :workers]) ++
        get_requirements_keys([:money, :workers]),
      # this is basically all energy gen

      get_requirements_keys([:money, :energy]),
      Enum.sort_by(rest_of_them, &buildables_flat()[&1].level, :desc)

      # get_requirements_keys([:energy, :money, :workers]),
      # get_requirements_keys([:energy, :area]),
      # get_requirements_keys([:energy, :workers]),
      # # parks
      # get_requirements_keys([:money, :area]),
      # get_requirements_keys([:energy, :area, :money]),
      # get_requirements_keys([:energy, :area, :workers]),
      # get_requirements_keys([:energy, :area, :money, :workers]),
      # get_requirements_keys([:energy, :area, :money, :workers, :steel, :sulfur])
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
