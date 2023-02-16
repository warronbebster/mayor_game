# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{BuildableMetadata, Details}
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  @typedoc """
      this makes a type for %Buildable{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          details: Details.t(),
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
        high_rises: buildables_flat().high_rises
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
        office_buildings: buildables_flat().office_buildings,
        distribution_centers: buildables_flat().distribution_centers
      },
      entertainment: %{
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas
      },
      health: %{
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
      },
      combat: %{
        air_bases: buildables_flat().air_bases,
        defense_bases: buildables_flat().defense_bases
      }
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
        high_rises: buildables_flat().high_rises
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
        libraries: buildables_flat().libraries
      ],
      work: [
        retail_shops: buildables_flat().retail_shops,
        factories: buildables_flat().factories,
        mines: buildables_flat().mines,
        office_buildings: buildables_flat().office_buildings,
        distribution_centers: buildables_flat().distribution_centers
      ],
      entertainment: [
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas
      ],
      health: [
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
      ],
      combat: [
        air_bases: buildables_flat().air_bases,
        defense_bases: buildables_flat().defense_bases
      ]
    ]
  end

  def buildables_flat do
    %{
      huts: %BuildableMetadata{
        level: 0,
        title: :huts,
        price: 10,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :single_family_homes,
        price: 100,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :multi_family_homes,
        price: 200,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :homeless_shelters,
        price: 100,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :apartments,
        price: 800,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :micro_apartments,
        price: 1_300,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :high_rises,
        price: 6_000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          area: 2,
          energy: 150
        },
        produces: %{
          housing: 100,
          pollution: 10
        }
      },
      # roads ————————————————————————————————————
      roads: %BuildableMetadata{
        level: 0,
        title: :roads,
        price: 200,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :highways,
        price: 400,
        multipliers: %{
          region: %{
            health: %{forest: 0.7, mountain: 0.7, desert: 0.9, lake: 0.7}
          }
        },
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :airports,
        price: 2000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :subway_lines,
        price: 2000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :bus_lines,
        price: 70,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :bike_lanes,
        price: 60,
        purchasable: true,
        purchasable_reason: "valid",
        requires: nil,
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
              mountain: 0.7,
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
        level: 0,
        title: :bikeshare_stations,
        price: 70,
        purchasable: true,
        purchasable_reason: "valid",
        multipliers: %{
          region: %{
            health: %{
              forest: 1.3,
              mountain: 1.4
            },
            fun: %{
              ocean: 1.5,
              mountain: 0.7,
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
        level: 0,
        title: :coal_plants,
        price: 500,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 1,
        title: :natural_gas_plants,
        price: 800,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 1,
        title: :wind_turbines,
        price: 1000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 2,
        title: :solar_plants,
        price: 2000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 3,
        title: :nuclear_plants,
        price: 5000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 2,
        title: :dams,
        price: 5000,
        purchasable: true,
        purchasable_reason: "valid",
        multipliers: %{
          region: %{
            energy: %{
              mountain: 1.5
            }
          },
          season: %{
            energy: %{
              winter: 0.7,
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
        level: 4,
        title: :fusion_reactors,
        price: 50_000_000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 10_000,
          uranium: 50,
          area: 10,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          energy: 100_000
        }
      },
      # Carbon Capture Plants ————————————————————————————————————
      carbon_capture_plants: %BuildableMetadata{
        level: 5,
        title: :carbon_capture_plants,
        price: 10000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :parks,
        price: 20,
        purchasable: true,
        purchasable_reason: "valid",
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
              mountain: 0.7,
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
      # LIBRARIES ————————————————————————————————————
      libraries: %BuildableMetadata{
        level: 2,
        title: :libraries,
        price: 1000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 10,
          area: 2,
          energy: 200,
          workers: %{count: 4, level: 2}
        }
        # todo: make random
        # produces: %{
        #   education: &%{5 => &1}
        # }
      },
      # SCHOOLS ————————————————————————————————————
      schools: %BuildableMetadata{
        level: 0,
        title: :schools,
        price: 2000,
        education_level: 1,
        capacity: 10,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 1,
        title: :middle_schools,
        price: 3000,
        education_level: 2,
        capacity: 10,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 40,
          energy: 800,
          area: 7,
          workers: %{count: 10, level: 1}
        },
        produces: %{
          education: %{2 => 10}
        }
      },
      # HIGH SCHOOLS ————————————————————————————————————
      high_schools: %BuildableMetadata{
        level: 2,
        title: :high_schools,
        price: 4000,
        education_level: 3,
        capacity: 10,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 3,
        title: :universities,
        price: 6500,
        education_level: 4,
        capacity: 10,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 4,
        title: :research_labs,
        price: 9000,
        education_level: 5,
        capacity: 5,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 5,
        title: :retail_shops,
        price: 1000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 2,
          energy: 100,
          area: 2,
          workers: %{count: 3, level: 0}
        }
      },
      # FACTORIES ————————————————————————————————————
      factories: %BuildableMetadata{
        level: 0,
        title: :factories,
        price: 5000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :mines,
        price: 5000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 250,
          energy: 1900,
          area: 25,
          workers: %{count: 30, level: 0}
        },
        produces: %{
          health: -5,
          pollution: 10,
          sulfur: 1
          # uranium: 1,
          # gold: 1,
        }
      },
      # OFFICE BUILDINGS ————————————————————————————————————
      office_buildings: %BuildableMetadata{
        level: 1,
        title: :office_buildings,
        price: 40_000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 5,
          energy: 800,
          area: 2,
          workers: %{count: 20, level: 1}
        }
      },
      # DISTRIBUTION CENTERS ————————————————————————————————
      distribution_centers: %BuildableMetadata{
        level: 0,
        title: :distribution_centers,
        price: 100_000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :theatres,
        price: 3000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 0,
        title: :arenas,
        price: 60_000,
        purchasable: true,
        purchasable_reason: "valid",
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
      # HOSPITALS ————————————————————————————————————
      hospitals: %BuildableMetadata{
        level: 2,
        title: :hospitals,
        price: 60_000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 4,
        title: :doctor_offices,
        price: 30_000,
        purchasable: true,
        purchasable_reason: "valid",
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
        level: 5,
        title: :air_bases,
        price: 100_000_000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 5000,
          steel: 50,
          sulfur: 5,
          energy: 5000,
          area: 500,
          workers: %{count: 10, level: 5}
        },
        produces: %{
          missiles: 1
        }
      },
      # AIR BASES ————————————————————————————————————
      defense_bases: %BuildableMetadata{
        level: 2,
        title: :defense_bases,
        price: 50_000_000,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 2000,
          energy: 2500,
          area: 100,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          shields: 1
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
      get_requirements_keys([:money, :workers]),
      # ^ bus lines and subways
      get_requirements_keys([:area, :workers]),
      # this is basically all energy gen
      get_requirements_keys([:money, :energy]),
      # ^ airports
      get_requirements_keys([:area, :money, :workers]),
      # this is basically all energy gen

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
