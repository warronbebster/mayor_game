# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset

  # ignore upgrades when printing?
  @derive {Jason.Encoder, except: [:upgrades]}

  # uhhhh this makes a type for %Buildable that's callable with MayorGame.City.Buildable.t()
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          enabled: boolean,
          reason: list,
          details: map,
          upgrades: list
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

    @doc false
    def changeset(buildable, attrs \\ %{}) do
      buildable
      |> cast(attrs, [:enabled, :reason, :upgrades])
    end
  end

  @spec upgradedStatMap(Buildable.t()) :: Buildable.t()
  def upgradedStatMap(buildable) do
    IO.inspect(buildable)

    # first check if an upgrade is purchased (is the string in the :upgrades array)
    # then check what those upgrades touch
    #
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
        multi_family_homes: %{
          price: 60,
          fits: 6,
          daily_cost: 0,
          area_required: 1,
          energy_required: 18,
          purchasable: true,
          purchasable_reason: "valid"
        },
        homeless_shelter: %{
          price: 60,
          fits: 20,
          daily_cost: 10,
          area_required: 5,
          energy_required: 70,
          purchasable: true,
          purchasable_reason: "valid"
        },
        apartments: %{
          price: 60,
          fits: 20,
          daily_cost: 0,
          area_required: 10,
          energy_required: 90,
          purchasable: true,
          purchasable_reason: "valid"
        },
        micro_apartments: %{
          price: 80,
          fits: 20,
          daily_cost: 0,
          area_required: 5,
          energy_required: 50,
          purchasable: true,
          purchasable_reason: "valid"
        },
        high_rises: %{
          price: 200,
          fits: 100,
          daily_cost: 0,
          area_required: 2,
          energy_required: 150,
          purchasable: true,
          purchasable_reason: "valid"
        }
      },
      transit: %{
        roads: %{
          price: 20,
          daily_cost: 0,
          jobs: 0,
          job_level: 0,
          sprawl: 10,
          area: 10,
          purchasable: true,
          purchasable_reason: "valid"
        },
        highways: %{
          price: 40,
          daily_cost: 0,
          jobs: 0,
          job_level: 0,
          sprawl: 20,
          area: 20,
          purchasable: true,
          purchasable_reason: "valid"
        },
        airports: %{
          price: 200,
          daily_cost: 10,
          jobs: 10,
          job_level: 0,
          sprawl: 5,
          area: 10,
          energy_required: 150,
          purchasable: true,
          purchasable_reason: "valid"
        },
        bus_lines: %{
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
        subway_lines: %{
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
        bike_lanes: %{
          price: 60,
          daily_cost: 0,
          jobs: 0,
          job_level: 0,
          sprawl: 0,
          area: 10,
          energy_required: 0,
          purchasable: true,
          purchasable_reason: "valid"
        },
        bikeshare_stations: %{
          price: 70,
          daily_cost: 0,
          jobs: 0,
          job_level: 0,
          sprawl: 0,
          area: 10,
          energy_required: 0,
          purchasable: true,
          purchasable_reason: "valid"
        }
      },
      energy: %{
        coal_plants: %{
          price: 20,
          daily_cost: 10,
          jobs: 30,
          job_level: 0,
          energy: 3500,
          pollution: 10,
          area_required: 5,
          region_energy_multipliers: %{mountain: 1.3},
          season_energy_multipliers: %{},
          purchasable: true,
          purchasable_reason: "valid"
        },
        wind_turbines: %{
          price: 100,
          daily_cost: 3,
          jobs: 10,
          job_level: 1,
          energy: 600,
          pollution: 0,
          area_required: 5,
          region_energy_multipliers: %{ocean: 1.3, desert: 1.1},
          season_energy_multipliers: %{spring: 1.2},
          purchasable: true,
          purchasable_reason: "valid"
        },
        solar_plants: %{
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
        nuclear_plants: %{
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
        dam: %{
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
        }
      },
      civic: %{
        parks: %{
          price: 20,
          daily_cost: 5,
          area_required: 10,
          energy_required: 12,
          purchasable: true,
          purchasable_reason: "valid"
        },
        libraries: %{
          price: 20,
          daily_cost: 10,
          area_required: 1,
          energy_required: 200,
          purchasable: true,
          purchasable_reason: "valid"
        }
      },
      education: %{
        schools: %{
          price: 20,
          daily_cost: 10,
          jobs: 10,
          job_level: 1,
          education_level: 1,
          capacity: 10,
          area_required: 5,
          energy_required: 800,
          purchasable: true,
          purchasable_reason: "valid"
        },
        middle_schools: %{
          price: 20,
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
        high_schools: %{
          price: 20,
          daily_cost: 10,
          jobs: 10,
          job_level: 1,
          education_level: 3,
          capacity: 10,
          area_required: 5,
          energy_required: 800,
          purchasable: true,
          purchasable_reason: "valid"
        },
        universities: %{
          price: 20,
          daily_cost: 15,
          jobs: 10,
          job_level: 2,
          education_level: 4,
          capacity: 10,
          area_required: 10,
          energy_required: 1200,
          purchasable: true,
          purchasable_reason: "valid"
        },
        research_labs: %{
          price: 20,
          daily_cost: 15,
          jobs: 10,
          job_level: 3,
          education_level: 5,
          capacity: 5,
          area_required: 3,
          energy_required: 600,
          purchasable: true,
          purchasable_reason: "valid"
        }
      },
      work: %{
        retail_shops: %{
          price: 20,
          daily_cost: 5,
          jobs: 5,
          job_level: 0,
          area_required: 2,
          energy_required: 50,
          purchasable: true,
          purchasable_reason: "valid"
        },
        factories: %{
          price: 20,
          daily_cost: 5,
          jobs: 20,
          job_level: 0,
          area_required: 10,
          energy_required: 1900,
          purchasable: true,
          purchasable_reason: "valid"
        },
        office_buildings: %{
          price: 20,
          daily_cost: 5,
          jobs: 20,
          job_level: 1,
          area_required: 5,
          energy_required: 800,
          purchasable: true,
          purchasable_reason: "valid"
        }
      },
      entertainment: %{
        theatres: %{
          price: 20,
          daily_cost: 5,
          jobs: 10,
          job_level: 0,
          area_required: 5,
          energy_required: 300,
          purchasable: true,
          purchasable_reason: "valid"
        },
        arenas: %{
          price: 20,
          daily_cost: 5,
          jobs: 20,
          job_level: 0,
          area_required: 10,
          energy_required: 500,
          purchasable: true,
          purchasable_reason: "valid"
        }
      },
      health: %{
        hospitals: %{
          price: 40,
          daily_cost: 5,
          jobs: 30,
          job_level: 2,
          area_required: 20,
          energy_required: 400,
          purchasable: true,
          purchasable_reason: "valid"
        },
        doctor_offices: %{
          price: 20,
          daily_cost: 5,
          jobs: 10,
          job_level: 4,
          area_required: 4,
          energy_required: 50,
          purchasable: true,
          purchasable_reason: "valid"
        }
      }
    }
  end

  @doc """
  generates and returns a list [] of buildables in atom form
  """
  def buildables_list do
    Enum.reduce(buildables(), [], fn {_categoryName, buildings}, acc ->
      Enum.reduce(buildings, [], fn {building_type, _building_options}, acc2 ->
        [building_type | acc2]
      end) ++
        acc
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
