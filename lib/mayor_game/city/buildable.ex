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
      housing: %{
        huts: buildables_flat().huts,
        single_family_homes: buildables_flat().single_family_homes,
        multi_family_homes: buildables_flat().multi_family_homes,
        homeless_shelters: buildables_flat().homeless_shelters,
        apartments: buildables_flat().apartments,
        micro_apartments: buildables_flat().micro_apartments,
        high_rises: buildables_flat().high_rises
      },
      education: %{
        schools: buildables_flat().schools,
        middle_schools: buildables_flat().middle_schools,
        high_schools: buildables_flat().high_schools,
        universities: buildables_flat().universities,
        research_labs: buildables_flat().research_labs
      },
      civic: %{
        parks: buildables_flat().parks,
        libraries: buildables_flat().libraries
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
    ]
  end

  def buildables_flat do
    %{
      huts: %BuildableMetadata{
        price: 5,
        fits: 1,
        daily_cost: 0,
        area_required: 1,
        energy_required: 0,
        purchasable: true,
        purchasable_reason: "valid"
      },
      single_family_homes: %BuildableMetadata{
        price: 20,
        fits: 2,
        daily_cost: 0,
        area_required: 1,
        energy_required: 12,
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
            requirements: [:upgrade_1],
            function: %{energy_required: &(&1 - 5)}
          }
        },
        purchasable_reason: "valid"
      },
      multi_family_homes: %BuildableMetadata{
        price: 60,
        fits: 6,
        daily_cost: 0,
        area_required: 1,
        energy_required: 18,
        purchasable: true,
        purchasable_reason: "valid"
      },
      homeless_shelters: %BuildableMetadata{
        price: 60,
        fits: 20,
        daily_cost: 10,
        area_required: 5,
        energy_required: 70,
        purchasable: true,
        purchasable_reason: "valid"
      },
      apartments: %BuildableMetadata{
        price: 60,
        fits: 20,
        daily_cost: 0,
        area_required: 10,
        energy_required: 90,
        purchasable: true,
        purchasable_reason: "valid"
      },
      micro_apartments: %BuildableMetadata{
        price: 80,
        fits: 20,
        daily_cost: 0,
        area_required: 5,
        energy_required: 50,
        purchasable: true,
        purchasable_reason: "valid"
      },
      high_rises: %BuildableMetadata{
        price: 200,
        fits: 100,
        daily_cost: 0,
        area_required: 2,
        energy_required: 150,
        purchasable: true,
        purchasable_reason: "valid"
      },
      roads: %BuildableMetadata{
        price: 20,
        daily_cost: 0,
        jobs: 0,
        job_level: 0,
        sprawl: 10,
        area: 10,
        health: -1,
        purchasable: true,
        purchasable_reason: "valid"
      },
      highways: %BuildableMetadata{
        price: 40,
        daily_cost: 0,
        jobs: 0,
        job_level: 0,
        sprawl: 20,
        area: 20,
        health: -4,
        region_health_multipliers: %{forest: 0.7, mountain: 0.7, desert: 0.9, lake: 0.7},
        purchasable: true,
        purchasable_reason: "valid"
      },
      airports: %BuildableMetadata{
        price: 200,
        daily_cost: 10,
        jobs: 10,
        job_level: 0,
        sprawl: 5,
        area: 10,
        health: -2,
        energy_required: 150,
        purchasable: true,
        purchasable_reason: "valid"
      },
      bus_lines: %BuildableMetadata{
        price: 70,
        daily_cost: 30,
        jobs: 10,
        job_level: 0,
        sprawl: 3,
        area: 50,
        energy_required: 30,
        purchasable: true,
        purchasable_reason: "valid"
      },
      subway_lines: %BuildableMetadata{
        price: 200,
        daily_cost: 40,
        jobs: 10,
        job_level: 0,
        sprawl: 1,
        area: 1000,
        energy_required: 10000,
        purchasable: true,
        purchasable_reason: "valid"
      },
      bike_lanes: %BuildableMetadata{
        price: 60,
        daily_cost: 0,
        jobs: 0,
        job_level: 0,
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
        purchasable: true,
        purchasable_reason: "valid"
      },
      bikeshare_stations: %BuildableMetadata{
        price: 70,
        daily_cost: 0,
        jobs: 0,
        job_level: 0,
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
        purchasable: true,
        purchasable_reason: "valid"
      },
      coal_plants: %BuildableMetadata{
        price: 20,
        daily_cost: 10,
        jobs: 5,
        job_level: 0,
        energy: 3500,
        pollution: 10,
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
        purchasable_reason: "valid"
      },
      wind_turbines: %BuildableMetadata{
        price: 100,
        daily_cost: 3,
        jobs: 10,
        job_level: 1,
        energy: 600,
        pollution: 0,
        area_required: 5,
        region_health_multipliers: %{ocean: 1.2, desert: 1.2},
        region_energy_multipliers: %{ocean: 1.3, desert: 1.5},
        season_energy_multipliers: %{spring: 1.2, fall: 1.2},
        purchasable: true,
        purchasable_reason: "valid"
      },
      solar_plants: %BuildableMetadata{
        price: 200,
        daily_cost: 3,
        jobs: 10,
        job_level: 2,
        energy: 500,
        pollution: 0,
        area_required: 5,
        region_energy_multipliers: %{desert: 1.5, ocean: 1.2, forest: 0.7},
        season_energy_multipliers: %{spring: 1.2, summer: 1.5, winter: 0.7},
        purchasable: true,
        purchasable_reason: "valid"
      },
      nuclear_plants: %BuildableMetadata{
        price: 2000,
        daily_cost: 50,
        jobs: 10,
        job_level: 3,
        energy: 5000,
        pollution: 0,
        area_required: 3,
        region_energy_multipliers: %{},
        season_energy_multipliers: %{},
        purchasable: true,
        purchasable_reason: "valid"
      },
      dams: %BuildableMetadata{
        price: 1000,
        daily_cost: 50,
        jobs: 10,
        job_level: 2,
        energy: 2000,
        pollution: 0,
        area_required: 10,
        region_energy_multipliers: %{mountain: 1.5},
        season_energy_multipliers: %{winter: 0.7, spring: 1.3},
        purchasable: true,
        purchasable_reason: "valid"
      },
      carbon_capture_plants: %BuildableMetadata{
        price: 2000,
        daily_cost: 50,
        jobs: 10,
        job_level: 2,
        energy: 0,
        pollution: -20,
        health: 1,
        area_required: 10,
        region_energy_multipliers: %{},
        season_energy_multipliers: %{},
        purchasable: true,
        purchasable_reason: "valid"
      },
      parks: %BuildableMetadata{
        price: 20,
        daily_cost: 5,
        area_required: 10,
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
        purchasable: true,
        purchasable_reason: "valid"
      },
      libraries: %BuildableMetadata{
        price: 200,
        daily_cost: 10,
        area_required: 1,
        jobs: 4,
        job_level: 2,
        energy_required: 200,
        purchasable: true,
        purchasable_reason: "valid"
      },
      schools: %BuildableMetadata{
        price: 200,
        daily_cost: 10,
        jobs: 10,
        job_level: 1,
        education_level: 1,
        capacity: 10,
        area_required: 5,
        energy_required: 600,
        upgrades: %{
          extra_classroom: %{
            cost: 5,
            description: "+5 capacity",
            requirements: [],
            function: %{capacity: &(&1 + 5)}
          }
        },
        purchasable: true,
        purchasable_reason: "valid"
      },
      middle_schools: %BuildableMetadata{
        price: 300,
        daily_cost: 10,
        jobs: 5,
        job_level: 1,
        education_level: 2,
        capacity: 5,
        area_required: 5,
        energy_required: 800,
        purchasable: true,
        purchasable_reason: "valid"
      },
      high_schools: %BuildableMetadata{
        price: 400,
        daily_cost: 10,
        jobs: 10,
        job_level: 2,
        education_level: 3,
        capacity: 10,
        area_required: 5,
        energy_required: 800,
        purchasable: true,
        purchasable_reason: "valid"
      },
      universities: %BuildableMetadata{
        price: 650,
        daily_cost: 15,
        jobs: 10,
        job_level: 3,
        education_level: 4,
        capacity: 10,
        area_required: 10,
        energy_required: 1200,
        purchasable: true,
        purchasable_reason: "valid"
      },
      research_labs: %BuildableMetadata{
        price: 900,
        daily_cost: 15,
        jobs: 10,
        job_level: 4,
        education_level: 5,
        capacity: 5,
        area_required: 3,
        energy_required: 600,
        purchasable: true,
        purchasable_reason: "valid"
      },
      retail_shops: %BuildableMetadata{
        price: 200,
        daily_cost: 5,
        jobs: 5,
        job_level: 0,
        area_required: 2,
        energy_required: 50,
        purchasable: true,
        purchasable_reason: "valid"
      },
      factories: %BuildableMetadata{
        price: 500,
        daily_cost: 5,
        jobs: 20,
        job_level: 0,
        area_required: 10,
        health: -3,
        energy_required: 1900,
        upgrades: %{
          solar_panel: %{
            cost: 25,
            description: "-500 energy_required",
            requirements: [],
            function: %{energy_required: &(&1 - 500)}
          }
        },
        purchasable: true,
        purchasable_reason: "valid"
      },
      office_buildings: %BuildableMetadata{
        price: 400,
        daily_cost: 5,
        jobs: 20,
        job_level: 1,
        area_required: 5,
        energy_required: 800,
        purchasable: true,
        purchasable_reason: "valid"
      },
      theatres: %BuildableMetadata{
        price: 300,
        daily_cost: 5,
        jobs: 10,
        job_level: 0,
        fun: 5,
        area_required: 5,
        energy_required: 300,
        purchasable: true,
        purchasable_reason: "valid"
      },
      arenas: %BuildableMetadata{
        price: 600,
        daily_cost: 5,
        jobs: 20,
        job_level: 0,
        fun: 10,
        area_required: 10,
        energy_required: 500,
        purchasable: true,
        purchasable_reason: "valid"
      },
      hospitals: %BuildableMetadata{
        price: 600,
        daily_cost: 5,
        jobs: 10,
        job_level: 2,
        health: 10,
        area_required: 20,
        energy_required: 400,
        purchasable: true,
        purchasable_reason: "valid"
      },
      doctor_offices: %BuildableMetadata{
        price: 300,
        daily_cost: 5,
        jobs: 10,
        job_level: 4,
        health: 15,
        area_required: 4,
        energy_required: 50,
        purchasable: true,
        purchasable_reason: "valid"
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
