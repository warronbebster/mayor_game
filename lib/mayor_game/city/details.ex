defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Buildable, Town}

  @timestamps_opts [type: :utc_datetime]

  # @derive {Inspect, except: [:town]}

  # todo: figure out how to generate AST for paramaterized types
  # @keys Buildable.buildables_list()
  # @type key :: unquote(Enum.reduce(@keys, &{:|, [], [&1, &2]}))
  # https://elixirforum.com/t/dynamically-generate-typespecs-from-module-attribute-list/7078/12
  # https://elixir-lang.org/getting-started/meta/quote-and-unquote.html

  # make a type for %Details{}
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          town: Town.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          # homes
          single_family_homes: list(Buildable.t()),
          multi_family_homes: list(Buildable.t()),
          homeless_shelter: list(Buildable.t()),
          apartments: list(Buildable.t()),
          micro_apartments: list(Buildable.t()),
          high_rises: list(Buildable.t()),
          # transit
          roads: list(Buildable.t()),
          highways: list(Buildable.t()),
          airports: list(Buildable.t()),
          bus_lines: list(Buildable.t()),
          subway_lines: list(Buildable.t()),
          bike_lanes: list(Buildable.t()),
          bikeshare_stations: list(Buildable.t()),
          # energy
          coal_plants: list(Buildable.t()),
          wind_turbines: list(Buildable.t()),
          solar_plants: list(Buildable.t()),
          nuclear_plants: list(Buildable.t()),
          dams: list(Buildable.t()),
          # civic
          parks: list(Buildable.t()),
          libraries: list(Buildable.t()),
          # education
          schools: list(Buildable.t()),
          middle_schools: list(Buildable.t()),
          high_schools: list(Buildable.t()),
          universities: list(Buildable.t()),
          research_labs: list(Buildable.t()),
          # work
          retail_shops: list(Buildable.t()),
          factories: list(Buildable.t()),
          office_buildings: list(Buildable.t()),
          # entertainment
          theatres: list(Buildable.t()),
          arenas: list(Buildable.t()),
          # health
          hospitals: list(Buildable.t()),
          doctor_offices: list(Buildable.t())
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
