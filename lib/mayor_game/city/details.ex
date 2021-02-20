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
    field :airports, :integer
    field :bus_lines, :integer
    field :subway_lines, :integer
    # civic
    field :parks, :integer
    field :libraries, :integer
    # education
    field :schools, :integer
    field :universities, :integer
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

  def detail_buildables do
    %{
      housing: %{
        houses: %{price: 20, fits: 4, ongoing_price: 0},
        apartments: %{price: 20, fits: 20, ongoing_price: 0}
      },
      transit: %{
        roads: %{price: 20, fits: 4, ongoing_price: 0},
        airports: %{price: 200, fits: 4, ongoing_price: 10},
        bus_lines: %{price: 100, fits: 4, ongoing_price: 30},
        subway_lines: %{price: 200, fits: 4, ongoing_price: 40}
      },
      civic: %{
        parks: %{price: 20, ongoing_price: 5},
        libraries: %{price: 20, ongoing_price: 10}
      },
      education: %{
        schools: %{price: 20, fits: 4, ongoing_price: 20},
        universities: %{price: 20, fits: 4, ongoing_price: 20}
      },
      work: %{
        factories: %{price: 20, fits: 4, ongoing_price: 5},
        office_buildings: %{price: 20, fits: 4, ongoing_price: 5}
      },
      entertainment: %{
        theatres: %{price: 20, ongoing_price: 5},
        arenas: %{price: 20, ongoing_price: 5}
      }
    }
  end

  def buildables_list() do
    Enum.reduce(detail_buildables(), [], fn {_categoryName, buildings}, acc ->
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
