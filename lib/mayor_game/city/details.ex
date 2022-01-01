defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Buildable, Town, CombinedBuildable}

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
          single_family_homes: list(Buildable.t() | CombinedBuildable.t()),
          multi_family_homes: list(Buildable.t() | CombinedBuildable.t()),
          homeless_shelter: list(Buildable.t() | CombinedBuildable.t()),
          apartments: list(Buildable.t() | CombinedBuildable.t()),
          micro_apartments: list(Buildable.t() | CombinedBuildable.t()),
          high_rises: list(Buildable.t() | CombinedBuildable.t()),
          # transit
          roads: list(Buildable.t() | CombinedBuildable.t()),
          highways: list(Buildable.t() | CombinedBuildable.t()),
          airports: list(Buildable.t() | CombinedBuildable.t()),
          bus_lines: list(Buildable.t() | CombinedBuildable.t()),
          subway_lines: list(Buildable.t() | CombinedBuildable.t()),
          bike_lanes: list(Buildable.t() | CombinedBuildable.t()),
          bikeshare_stations: list(Buildable.t() | CombinedBuildable.t()),
          # energy
          coal_plants: list(Buildable.t() | CombinedBuildable.t()),
          wind_turbines: list(Buildable.t() | CombinedBuildable.t()),
          solar_plants: list(Buildable.t() | CombinedBuildable.t()),
          nuclear_plants: list(Buildable.t() | CombinedBuildable.t()),
          dams: list(Buildable.t() | CombinedBuildable.t()),
          # civic
          parks: list(Buildable.t() | CombinedBuildable.t()),
          libraries: list(Buildable.t() | CombinedBuildable.t()),
          # education
          schools: list(Buildable.t() | CombinedBuildable.t()),
          middle_schools: list(Buildable.t() | CombinedBuildable.t()),
          high_schools: list(Buildable.t() | CombinedBuildable.t()),
          universities: list(Buildable.t() | CombinedBuildable.t()),
          research_labs: list(Buildable.t() | CombinedBuildable.t()),
          # work
          retail_shops: list(Buildable.t() | CombinedBuildable.t()),
          factories: list(Buildable.t() | CombinedBuildable.t()),
          office_buildings: list(Buildable.t() | CombinedBuildable.t()),
          # entertainment
          theatres: list(Buildable.t() | CombinedBuildable.t()),
          arenas: list(Buildable.t() | CombinedBuildable.t()),
          # health
          hospitals: list(Buildable.t() | CombinedBuildable.t()),
          doctor_offices: list(Buildable.t() | CombinedBuildable.t())
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
