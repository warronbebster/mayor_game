defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset

  schema "details" do
    field :city_treasury, :integer
    # housing
    field :houses, :integer
    field :apartments, :integer
    # transit
    field :roads, :integer
    field :highways, :integer
    field :airports, :integer
    field :bus_lines, :integer
    field :subway_lines, :integer
    # infrastructure
    field :coal_plants, :integer
    field :wind_turbines, :integer
    field :solar_plants, :integer
    field :nuclear_plants, :integer
    # civic
    field :parks, :integer
    field :libraries, :integer
    # education
    field :schools, :integer
    field :universities, :integer
    field :research_labs, :integer
    # work
    field :factories, :integer
    field :office_buildings, :integer
    # entertainment
    field :theatres, :integer
    field :arenas, :integer

    # ok so basically
    # this "belongs to is called "city" but it belongs to the "info" schema
    # so there has to be a "whatever_id" field in the migration
    # automatically adds "_id" when looking for a foreign key, unless you set it
    belongs_to :info, MayorGame.City.Info

    timestamps()
  end

  def buildables do
    %{
      housing: %{
        houses: %{price: 20, fits: 4, daily_cost: 0},
        apartments: %{price: 20, fits: 20, daily_cost: 0}
      },
      transit: %{
        roads: %{price: 20, daily_cost: 0, jobs: 0, job_level: 0, sprawl: 10, mobility: 10},
        highways: %{price: 40, daily_cost: 0, jobs: 0, job_level: 0, sprawl: 20, mobility: 20},
        airports: %{price: 200, daily_cost: 10, jobs: 10, job_level: 0, sprawl: 5, mobility: 10},
        bus_lines: %{price: 100, daily_cost: 30, jobs: 10, job_level: 0, sprawl: 3, mobility: 50},
        subway_lines: %{
          price: 200,
          daily_cost: 40,
          jobs: 10,
          job_level: 0,
          sprawl: 1,
          mobility: 100
        }
      },
      infrastructure: %{
        coal_plants: %{price: 20, daily_cost: 10, jobs: 100, job_level: 0},
        wind_turbines: %{price: 100, daily_cost: 3, jobs: 10, job_level: 1},
        solar_plants: %{price: 200, daily_cost: 3, jobs: 10, job_level: 2},
        nuclear_plants: %{price: 20, daily_cost: 10, jobs: 100, job_level: 3}
      },
      civic: %{
        parks: %{price: 20, daily_cost: 5},
        libraries: %{price: 20, daily_cost: 10}
      },
      education: %{
        schools: %{price: 20, daily_cost: 20, jobs: 10, job_level: 1},
        universities: %{price: 20, daily_cost: 20, jobs: 10, job_level: 2},
        research_labs: %{price: 20, daily_cost: 20, jobs: 10, job_level: 3}
      },
      work: %{
        factories: %{price: 20, daily_cost: 5, jobs: 20, job_level: 0},
        office_buildings: %{price: 20, daily_cost: 5, jobs: 20, job_level: 1}
      },
      entertainment: %{
        theatres: %{price: 20, daily_cost: 5, jobs: 10, job_level: 0},
        arenas: %{price: 20, daily_cost: 5, jobs: 20, job_level: 0}
      }
    }
  end

  def buildables_list() do
    Enum.reduce(buildables(), [], fn {_categoryName, buildings}, acc ->
      Enum.reduce(buildings, [], fn {building_type, _building_options}, acc2 ->
        [building_type | acc2]
      end) ++
        acc
    end)
  end

  @doc false
  def changeset(details, attrs) do
    detail_fields = buildables_list() ++ [:city_treasury, :info_id]

    details
    # this basically defines the fields users can change
    |> cast(attrs, detail_fields)
    # and this is required fields
    |> validate_required(detail_fields)
  end
end
