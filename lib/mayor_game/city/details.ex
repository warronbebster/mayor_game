defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Buildable, Town}

  @timestamps_opts [type: :utc_datetime]

  @derive {Inspect, except: [:town]}

  # todo: figure out how to generate AST for paramaterized types
  # @keys Buildable.buildables_list()
  # @type key :: unquote(Enum.reduce(@keys, &{:|, [], [&1, &2]}))
  # https://elixirforum.com/t/dynamically-generate-typespecs-from-module-attribute-list/7078/12
  # https://elixir-lang.org/getting-started/meta/quote-and-unquote.html

  # make a type for %Details{}
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          town: map,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          # homes
          single_family_homes: Buildable.t(),
          multi_family_homes: Buildable.t(),
          homeless_shelter: Buildable.t(),
          apartments: Buildable.t(),
          micro_apartments: Buildable.t(),
          high_rises: Buildable.t(),
          # transit
          roads: Buildable.t(),
          highways: Buildable.t(),
          airports: Buildable.t(),
          bus_lines: Buildable.t(),
          subway_lines: Buildable.t(),
          bike_lanes: Buildable.t(),
          bikeshare_stations: Buildable.t(),
          # energy
          coal_plants: Buildable.t(),
          wind_turbines: Buildable.t(),
          solar_plants: Buildable.t(),
          nuclear_plants: Buildable.t(),
          dams: Buildable.t(),
          # civic
          parks: Buildable.t(),
          libraries: Buildable.t(),
          # education
          schools: Buildable.t(),
          middle_schools: Buildable.t(),
          high_schools: Buildable.t(),
          universities: Buildable.t(),
          research_labs: Buildable.t(),
          # work
          retail_shops: Buildable.t(),
          factories: Buildable.t(),
          office_buildings: Buildable.t(),
          # entertainment
          theatres: Buildable.t(),
          arenas: Buildable.t(),
          # health
          hospitals: Buildable.t(),
          doctor_offices: Buildable.t()
        }

  schema "details" do
    field :city_treasury, :integer

    # add buildables to schema dynamically
    for buildable <- Buildable.buildables_list() do
      has_many buildable, {to_string(buildable), Buildable}
    end

    # ok so basically this is a macro
    # this belongs to the "town" schema
    # so there has to be a "whatever_id" has_many in the migration
    # automatically adds "_id" when looking for a foreign key, unless you set it
    belongs_to :town, Town

    timestamps()
  end

  @doc false
  def changeset(details, attrs) do
    detail_fields = [:city_treasury, :town_id]

    details
    # this basically defines the has_manys users can change
    |> cast(attrs, detail_fields)
    |> validate_required(detail_fields)
  end
end
