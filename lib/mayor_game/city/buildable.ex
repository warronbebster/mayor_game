# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:upgrades]}

  schema "buildable" do
    # has an id built-in?
    field :enabled, :boolean
    field :reason, {:array, :string}
    field :upgrades, :map
    belongs_to :details, MayorGame.City.Details

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
        single_family_homes: %{
          price: 20,
          fits: 2,
          daily_cost: 0,
          area_required: 1,
          energy_required: 12
        },
        multi_family_homes: %{
          price: 60,
          fits: 6,
          daily_cost: 0,
          area_required: 1,
          energy_required: 18
        },
        homeless_shelter: %{
          price: 60,
          fits: 20,
          daily_cost: 10,
          area_required: 5,
          energy_required: 70
        },
        apartments: %{price: 60, fits: 20, daily_cost: 0, area_required: 10, energy_required: 90},
        micro_apartments: %{
          price: 80,
          fits: 20,
          daily_cost: 0,
          area_required: 5,
          energy_required: 50
        },
        high_rises: %{
          price: 200,
          fits: 100,
          daily_cost: 0,
          area_required: 2,
          energy_required: 150
        }
      },
      transit: %{
        roads: %{price: 20, daily_cost: 0, jobs: 0, job_level: 0, sprawl: 10, area: 10},
        highways: %{price: 40, daily_cost: 0, jobs: 0, job_level: 0, sprawl: 20, area: 20},
        airports: %{
          price: 200,
          daily_cost: 10,
          jobs: 10,
          job_level: 0,
          sprawl: 5,
          area: 10,
          energy_required: 150
        },
        bus_lines: %{
          price: 100,
          daily_cost: 30,
          jobs: 10,
          job_level: 0,
          sprawl: 3,
          area: 50,
          energy_required: 30
        },
        subway_lines: %{
          price: 200,
          daily_cost: 40,
          jobs: 10,
          job_level: 0,
          sprawl: 1,
          area: 1000,
          energy_required: 10000
        },
        bike_lanes: %{
          price: 100,
          daily_cost: 0,
          jobs: 0,
          job_level: 0,
          sprawl: 0,
          area: 10,
          energy_required: 0
        },
        bikeshare_stations: %{
          price: 100,
          daily_cost: 0,
          jobs: 0,
          job_level: 0,
          sprawl: 0,
          area: 10,
          energy_required: 0
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
          region_energy_multipliers: %{"mountain" => 1.2},
          season_energy_multipliers: %{}
        },
        wind_turbines: %{
          price: 100,
          daily_cost: 3,
          jobs: 10,
          job_level: 1,
          energy: 600,
          pollution: 0,
          area_required: 5,
          region_energy_multipliers: %{"ocean" => 1.3, "desert" => 1.1},
          season_energy_multipliers: %{spring: 1.2}
        },
        solar_plants: %{
          price: 200,
          daily_cost: 3,
          jobs: 10,
          job_level: 2,
          energy: 500,
          pollution: 0,
          area_required: 5,
          region_energy_multipliers: %{"desert" => 1.5, "forest" => 0.8},
          season_energy_multipliers: %{spring: 1.2, summer: 1.5, winter: 0.7}
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
          season_energy_multipliers: %{}
        }
      },
      civic: %{
        parks: %{price: 20, daily_cost: 5, area_required: 10, energy_required: 12},
        libraries: %{price: 20, daily_cost: 10, area_required: 1, energy_required: 200}
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
          energy_required: 800
        },
        middle_schools: %{
          price: 20,
          daily_cost: 10,
          jobs: 5,
          job_level: 1,
          education_level: 2,
          capacity: 5,
          area_required: 5,
          energy_required: 800
        },
        high_schools: %{
          price: 20,
          daily_cost: 10,
          jobs: 10,
          job_level: 1,
          education_level: 3,
          capacity: 10,
          area_required: 5,
          energy_required: 800
        },
        universities: %{
          price: 20,
          daily_cost: 15,
          jobs: 10,
          job_level: 2,
          education_level: 4,
          capacity: 10,
          area_required: 10,
          energy_required: 1200
        },
        research_labs: %{
          price: 20,
          daily_cost: 15,
          jobs: 10,
          job_level: 3,
          education_level: 5,
          capacity: 5,
          area_required: 3,
          energy_required: 600
        }
      },
      work: %{
        retail_shops: %{
          price: 20,
          daily_cost: 5,
          jobs: 5,
          job_level: 0,
          area_required: 2,
          energy_required: 50
        },
        factories: %{
          price: 20,
          daily_cost: 5,
          jobs: 20,
          job_level: 0,
          area_required: 10,
          energy_required: 1900
        },
        office_buildings: %{
          price: 20,
          daily_cost: 5,
          jobs: 20,
          job_level: 1,
          area_required: 5,
          energy_required: 800
        }
      },
      entertainment: %{
        theatres: %{
          price: 20,
          daily_cost: 5,
          jobs: 10,
          job_level: 0,
          area_required: 5,
          energy_required: 300
        },
        arenas: %{
          price: 20,
          daily_cost: 5,
          jobs: 20,
          job_level: 0,
          area_required: 10,
          energy_required: 500
        }
      },
      health: %{
        hospitals: %{
          price: 20,
          daily_cost: 5,
          jobs: 30,
          job_level: 2,
          area_required: 20,
          energy_required: 400
        },
        doctor_offices: %{
          price: 20,
          daily_cost: 5,
          jobs: 10,
          job_level: 4,
          area_required: 4,
          energy_required: 50
        }
      }
    }
  end

  @doc """
  generates and returns a list [] of buildabless in atom form
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
