# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{BuildableMetadata, Details}
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  # ignore upgrades when printing?
  @derive {Jason.Encoder, except: [:upgrades]}

  @typedoc """
      this makes a type for %Buildable{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          enabled: boolean,
          reason: list(String.t()),
          details: Details.t(),
          upgrades: list(map),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  # schemas make elixir structs (in this case, %Buildable{})
  schema "buildable" do
    # has an id built-in?
    # is the buildable enabled
    field :enabled, :boolean
    # what's the reason it's enabled or not
    field :reason, {:array, :string}
    # what are the upgrades the buildable currently possesses
    field :upgrades, {:array, :string}
    belongs_to :details, MayorGame.City.Details

    timestamps()

    @doc false
    def changeset(buildable, attrs \\ %{}) do
      buildable
      |> cast(attrs, [:enabled, :reason, :upgrades])
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
        wind_turbines: buildables_flat().wind_turbines,
        solar_plants: buildables_flat().solar_plants,
        nuclear_plants: buildables_flat().nuclear_plants,
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
        office_buildings: buildables_flat().office_buildings
      },
      entertainment: %{
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas
      },
      health: %{
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
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
        wind_turbines: buildables_flat().wind_turbines,
        solar_plants: buildables_flat().solar_plants,
        nuclear_plants: buildables_flat().nuclear_plants,
        dams: buildables_flat().dams,
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
        office_buildings: buildables_flat().office_buildings
      ],
      entertainment: [
        theatres: buildables_flat().theatres,
        arenas: buildables_flat().arenas
      ],
      health: [
        hospitals: buildables_flat().hospitals,
        doctor_offices: buildables_flat().doctor_offices
      ]
    ]
  end

  def buildables_flat do
    %{
      huts: %BuildableMetadata{
        title: :huts,
        price: 5,
        fits: 1,
        money_required: 0,
        area_required: 1,
        energy_required: 0,
        energy_priority: 2,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
        requires: %{
          area: 1
        },
        produces: %{
          housing: 1
        }
      },
      # single family homes ————————————————————————————————————
      single_family_homes: %BuildableMetadata{
        title: :single_family_homes,
        price: 20,
        fits: 2,
        money_required: 0,
        area_required: 1,
        energy_required: 12,
        energy_priority: 2,
        purchasable: true,
        upgrades: %{
          more_room: %{
            cost: 5,
            description: "+1 fit",
            requirements: [],
            function: %{fits: &(&1 + 1)}
          },
          solar_panels: %{
            cost: 10,
            description: "-5 Energy required ",
            requirements: [:more_room],
            function: %{energy_required: &(&1 - 5)}
          }
        },
        purchasable_reason: "valid",
        job_priority: 0,
        requires: %{
          area: 1,
          energy: 12
        },
        produces: %{
          housing: 2
        }
      },
      # multi family homes ————————————————————————————————————
      multi_family_homes: %BuildableMetadata{
        title: :multi_family_homes,
        price: 60,
        fits: 6,
        money_required: 0,
        area_required: 1,
        energy_required: 18,
        energy_priority: 2,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
        requires: %{
          area: 1,
          energy: 18
        },
        produces: %{
          housing: 6
        }
      },
      # homeless shelters ————————————————————————————————————
      homeless_shelters: %BuildableMetadata{
        title: :homeless_shelters,
        price: 60,
        fits: 20,
        money_required: 100,
        area_required: 5,
        energy_required: 70,
        energy_priority: 2,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
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
        title: :apartments,
        price: 60,
        fits: 20,
        money_required: 0,
        area_required: 10,
        energy_required: 90,
        energy_priority: 2,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
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
        title: :micro_apartments,
        price: 80,
        fits: 20,
        money_required: 0,
        area_required: 5,
        energy_required: 50,
        energy_priority: 2,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
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
        title: :high_rises,
        price: 200,
        fits: 100,
        pollution: 10,
        money_required: 0,
        area_required: 2,
        energy_required: 150,
        energy_priority: 2,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
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
        title: :roads,
        price: 200,
        money_required: 0,
        job_level: 0,
        job_priority: 0,
        energy_priority: 0,
        sprawl: 10,
        pollution: 1,
        area: 10,
        health: -1,
        purchasable: true,
        purchasable_reason: "valid",
        produces: %{
          health: -1,
          sprawl: 10,
          area: 10,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.1)
        }
      },
      # highways ————————————————————————————————————
      highways: %BuildableMetadata{
        title: :highways,
        price: 400,
        money_required: 0,
        job_level: 0,
        job_priority: 0,
        energy_priority: 0,
        sprawl: 20,
        pollution: 2,
        area: 20,
        health: -4,
        region_health_multipliers: %{forest: 0.7, mountain: 0.7, desert: 0.9, lake: 0.7},
        purchasable: true,
        purchasable_reason: "valid",
        produces: %{
          health: -4,
          sprawl: 20,
          area: 20,
          # todo: some of these could be functions?
          pollution: &(&1 * 0.2)
        }
      },
      # Airports —————————————————————————————————————
      airports: %BuildableMetadata{
        title: :airports,
        price: 200,
        money_required: 10,
        workers_required: 10,
        job_level: 0,
        job_priority: 2,
        pollution: 3,
        sprawl: 5,
        area: 10,
        health: -2,
        energy_required: 150,
        energy_priority: 3,
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
          pollution: &(&1 * 0.2)
        }
      },
      # Bus Lines ————————————————————————————————————
      bus_lines: %BuildableMetadata{
        title: :bus_lines,
        price: 70,
        money_required: 30,
        workers_required: 10,
        job_level: 0,
        job_priority: 2,
        energy_priority: 0,
        sprawl: 3,
        area: 50,
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
      # Subway Lines ————————————————————————————————————
      subway_lines: %BuildableMetadata{
        title: :subway_lines,
        price: 2000,
        money_required: 40,
        workers_required: 10,
        job_level: 0,
        job_priority: 2,
        sprawl: 1,
        area: 1000,
        energy_required: 10000,
        energy_priority: 3,
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
      # Bike lanes ————————————————————————————————————
      bike_lanes: %BuildableMetadata{
        title: :bike_lanes,
        price: 60,
        money_required: 0,
        job_level: 0,
        job_priority: 0,
        sprawl: 0,
        area: 10,
        health: 2,
        region_health_multipliers: %{
          forest: 1.3,
          mountain: 1.4,
          lake: 1.1,
          desert: 1.1,
          ocean: 1.1
        },
        region_fun_multipliers: %{ocean: 1.5, mountain: 0.7, desert: 0.6},
        energy_required: 0,
        energy_priority: 3,
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
        title: :bikeshare_stations,
        price: 70,
        money_required: 0,
        job_level: 0,
        job_priority: 0,
        sprawl: 0,
        area: 10,
        health: 1,
        upgrades: %{
          more_stations: %{
            cost: 5,
            description: "+5 area",
            requirements: [],
            function: %{area: &(&1 + 5)}
          }
        },
        region_health_multipliers: %{forest: 1.3, mountain: 1.4},
        region_fun_multipliers: %{ocean: 1.5, mountain: 0.7, desert: 0.6},
        energy_required: 0,
        energy_priority: 3,
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
        title: :coal_plants,
        price: 500,
        money_required: 10,
        workers_required: 5,
        job_level: 0,
        job_priority: 3,
        energy: 2000,
        energy_priority: 0,
        pollution: 30,
        health: -10,
        area_required: 5,
        region_health_multipliers: %{
          forest: 0.7,
          mountain: 0.5,
          lake: 0.7,
          desert: 0.7,
          ocean: 0.7
        },
        region_energy_multipliers: %{mountain: 1.3},
        season_energy_multipliers: %{},
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
      # wind turbines ————————————————————————————————————
      wind_turbines: %BuildableMetadata{
        title: :wind_turbines,
        price: 1000,
        money_required: 30,
        workers_required: 10,
        job_level: 1,
        job_priority: 3,
        energy: 600,
        energy_priority: 0,
        pollution: 1,
        area_required: 5,
        region_health_multipliers: %{ocean: 1.2, desert: 1.2},
        region_energy_multipliers: %{ocean: 1.3, desert: 1.5},
        season_energy_multipliers: %{spring: 1.2, fall: 1.2},
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
        title: :solar_plants,
        price: 2000,
        money_required: 3,
        workers_required: 10,
        job_level: 2,
        job_priority: 3,
        energy: 500,
        energy_priority: 0,
        pollution: 0,
        area_required: 5,
        region_energy_multipliers: %{desert: 1.5, ocean: 1.2, forest: 0.7},
        season_energy_multipliers: %{spring: 1.2, summer: 1.5, winter: 0.7},
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
          money: 3,
          area: 5,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          energy: 500
        }
      },
      # Nuclear Plants ————————————————————————————————————
      nuclear_plants: %BuildableMetadata{
        title: :nuclear_plants,
        price: 10000,
        money_required: 50,
        workers_required: 10,
        job_level: 3,
        job_priority: 3,
        energy: 5000,
        energy_priority: 0,
        pollution: 0,
        area_required: 3,
        region_energy_multipliers: %{},
        season_energy_multipliers: %{},
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
        title: :dams,
        price: 5000,
        money_required: 30,
        workers_required: 5,
        job_level: 2,
        job_priority: 3,
        energy: 1000,
        energy_priority: 0,
        pollution: 0,
        area_required: 10,
        region_energy_multipliers: %{mountain: 1.5},
        season_energy_multipliers: %{winter: 0.7, spring: 1.3},
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
      # Carbon Capture Plants ————————————————————————————————————
      carbon_capture_plants: %BuildableMetadata{
        title: :carbon_capture_plants,
        price: 10000,
        money_required: 50,
        workers_required: 10,
        job_level: 5,
        job_priority: 3,
        pollution: -100,
        energy_priority: 0,
        health: 1,
        area_required: 10,
        region_energy_multipliers: %{},
        season_energy_multipliers: %{},
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
        title: :parks,
        price: 20,
        money_required: 5,
        area_required: 10,
        pollution: -1,
        fun: 3,
        health: 5,
        region_health_multipliers: %{
          ocean: 1.1,
          mountain: 1.4,
          desert: 1.1,
          forest: 1.3,
          lake: 1.1
        },
        region_fun_multipliers: %{ocean: 1.5, mountain: 0.7, desert: 1.1, forest: 1.2, lake: 1.2},
        energy_required: 12,
        energy_priority: 0,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
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
        title: :libraries,
        price: 200,
        money_required: 10,
        area_required: 1,
        workers_required: 4,
        job_level: 2,
        energy_required: 200,
        energy_priority: 0,
        purchasable: true,
        purchasable_reason: "valid",
        job_priority: 0,
        requires: %{
          money: 10,
          area: 2,
          energy: 200,
          workers: %{count: 4, level: 2}
        }
      },
      # SCHOOLS ————————————————————————————————————
      schools: %BuildableMetadata{
        title: :schools,
        price: 200,
        money_required: 10,
        workers_required: 10,
        job_level: 0,
        job_priority: 1,
        education_level: 1,
        capacity: 10,
        area_required: 5,
        energy_required: 600,
        energy_priority: 1,
        upgrades: %{
          extra_classroom: %{
            cost: 5,
            description: "+5 capacity",
            requirements: [],
            function: %{capacity: &(&1 + 5)}
          }
        },
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
        title: :middle_schools,
        price: 300,
        money_required: 10,
        workers_required: 5,
        job_level: 1,
        job_priority: 1,
        education_level: 2,
        capacity: 10,
        area_required: 5,
        energy_required: 800,
        energy_priority: 1,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 10,
          energy: 800,
          area: 5,
          workers: %{count: 10, level: 1}
        },
        produces: %{
          education: %{2 => 10}
        }
      },
      # HIGH SCHOOLS ————————————————————————————————————
      high_schools: %BuildableMetadata{
        title: :high_schools,
        price: 400,
        money_required: 10,
        workers_required: 10,
        job_level: 2,
        job_priority: 1,
        education_level: 3,
        capacity: 10,
        area_required: 5,
        energy_required: 800,
        energy_priority: 1,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 10,
          energy: 800,
          area: 5,
          workers: %{count: 10, level: 2}
        },
        produces: %{
          education: %{3 => 10}
        }
      },
      # UNIVERSITIES ————————————————————————————————————
      universities: %BuildableMetadata{
        title: :universities,
        price: 650,
        money_required: 15,
        workers_required: 10,
        job_level: 3,
        job_priority: 1,
        education_level: 4,
        capacity: 10,
        area_required: 10,
        energy_required: 1200,
        energy_priority: 1,
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
        title: :research_labs,
        price: 900,
        money_required: 15,
        workers_required: 10,
        job_level: 4,
        job_priority: 1,
        education_level: 5,
        capacity: 5,
        area_required: 3,
        energy_required: 600,
        energy_priority: 1,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 200,
          energy: 1200,
          area: 3,
          workers: %{count: 10, level: 4}
        },
        produces: %{
          education: %{5 => 10}
        }
      },
      # RETAIL SHOPS ————————————————————————————————————
      retail_shops: %BuildableMetadata{
        title: :retail_shops,
        price: 200,
        money_required: 5,
        workers_required: 5,
        job_level: 0,
        job_priority: 0,
        area_required: 2,
        energy_required: 50,
        energy_priority: 0,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 5,
          energy: 100,
          area: 2,
          workers: %{count: 3, level: 0}
        }
      },
      # FACTORIES ————————————————————————————————————
      factories: %BuildableMetadata{
        title: :factories,
        price: 500,
        money_required: 5,
        workers_required: 20,
        job_level: 0,
        job_priority: 0,
        area_required: 10,
        health: -3,
        energy_required: 1900,
        energy_priority: 0,
        upgrades: %{
          solar_panel: %{
            cost: 25,
            description: "-500 energy_required",
            requirements: [],
            function: %{energy_required: &(&1 - 500)}
          }
        },
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
          pollution: 1
        }
      },
      # OFFICE BUILDINGS ————————————————————————————————————
      office_buildings: %BuildableMetadata{
        title: :office_buildings,
        price: 400,
        money_required: 5,
        workers_required: 20,
        job_level: 1,
        job_priority: 0,
        area_required: 5,
        energy_required: 800,
        energy_priority: 0,
        purchasable: true,
        purchasable_reason: "valid",
        requires: %{
          money: 5,
          energy: 800,
          area: 2,
          workers: %{count: 20, level: 1}
        }
      },
      # THEATRES ————————————————————————————————————
      theatres: %BuildableMetadata{
        title: :theatres,
        price: 300,
        money_required: 5,
        workers_required: 10,
        job_level: 0,
        job_priority: 0,
        fun: 5,
        area_required: 5,
        energy_required: 300,
        energy_priority: 0,
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
        title: :arenas,
        price: 600,
        money_required: 5,
        workers_required: 20,
        job_level: 0,
        job_priority: 0,
        fun: 10,
        area_required: 10,
        energy_required: 500,
        energy_priority: 0,
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
        title: :hospitals,
        price: 600,
        money_required: 5,
        workers_required: 10,
        job_level: 2,
        job_priority: 0,
        health: 10,
        area_required: 20,
        energy_required: 400,
        energy_priority: 0,
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
        title: :doctor_offices,
        price: 300,
        money_required: 5,
        workers_required: 10,
        job_level: 4,
        job_priority: 0,
        health: 15,
        area_required: 4,
        energy_required: 50,
        energy_priority: 0,
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

    [
      needs_nothing,
      get_requirements_keys([:area]),
      get_requirements_keys([:money]),
      get_requirements_keys([:money, :energy]),
      get_requirements_keys([:money, :workers]),
      get_requirements_keys([:area, :workers]),
      # this is basically all energy gen
      get_requirements_keys([:area, :money, :workers]),
      # subway lines
      get_requirements_keys([:energy, :money, :workers]),
      get_requirements_keys([:energy, :area]),
      get_requirements_keys([:energy, :workers]),
      # parks
      get_requirements_keys([:money, :area]),
      get_requirements_keys([:energy, :area, :money]),
      get_requirements_keys([:energy, :area, :workers]),
      get_requirements_keys([:energy, :area, :money, :workers])
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
    Map.filter(buildables_flat(), fn {_cat, stats} ->
      check_requirements(stats.requires, list_of_reqs)
    end)
    |> Map.keys()
  end

  def sorted_buildables do
    Enum.filter(buildables_flat(), fn {_name, metadata} ->
      metadata.workers_required !== nil
    end)
    |> Enum.sort_by(&elem(&1, 1).job_priority, :desc)
    |> Enum.sort_by(&elem(&1, 1).job_level, :asc)
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
