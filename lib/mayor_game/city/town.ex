defmodule MayorGame.City.Town do
  @moduledoc """
      A %Town{} is the highest-level representation of a "town" in-game
      It contains:
      __meta__: Ecto.Schema.Metadata.t(),
      id: integer | nil,
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil,
      title: String.t(),
      region: String.t(),
      climate: String.t(),
      resources: map,
      logs: list(String.t()),
      tax_rates: map,
      user: %MayorGame.Auth.User{},
      citizens: list(Citizens.t()),
      pollution: integer,
      treasury: integer
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Details, Buildable}
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  # don't print these on inspect
  @derive {Inspect, except: [:logs, :citizens]}

  @typedoc """
      Type for %Town{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t ::
          %__MODULE__{
            __meta__: Ecto.Schema.Metadata.t(),
            id: integer | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil,
            title: String.t(),
            region: String.t(),
            climate: String.t(),
            resources: map,
            logs: list(String.t()),
            tax_rates: map,
            user: %MayorGame.Auth.User{},
            citizens: list(Citizens.t()),
            pollution: integer,
            treasury: integer,
            citizen_count: integer,
            steel: integer,
            missiles: integer,
            shields: integer,
            sulfur: integer,
            gold: integer,
            uranium: integer,
            patron: integer,
            huts: integer,
            single_family_homes: integer,
            multi_family_homes: integer,
            homeless_shelters: integer,
            apartments: integer,
            high_rises: integer,
            roads: integer,
            highways: integer,
            airports: integer,
            bus_lines: integer,
            subway_lines: integer,
            bike_lanes: integer,
            bikeshare_stations: integer,
            coal_plants: integer,
            wind_turbines: integer,
            solar_plants: integer,
            nuclear_plants: integer,
            dams: integer,
            carbon_capture_plants: integer,
            parks: integer,
            libraries: integer,
            schools: integer,
            middle_schools: integer,
            high_schools: integer,
            universities: integer,
            research_labs: integer,
            retail_shops: integer,
            factories: integer,
            mines: integer,
            office_buildings: integer,
            theatres: integer,
            arenas: integer,
            hospitals: integer,
            doctor_offices: integer,
            air_bases: integer,
            defense_bases: integer
          }

  schema "cities" do
    field(:title, :string)
    field(:region, :string)
    field(:climate, :string)
    field(:resources, :map)
    field(:pollution, :integer)
    field(:treasury, :integer)
    field(:citizen_count, :integer)
    field(:steel, :integer)
    field(:missiles, :integer)
    field(:shields, :integer)
    field(:sulfur, :integer)
    field(:gold, :integer)
    field(:uranium, :integer)

    field(:patron, :integer)

    # this corresponds to an elixir list
    field(:logs, {:array, :string})
    field(:tax_rates, :map)
    belongs_to(:user, MayorGame.Auth.User)

    # outline relationship between city and citizens
    # this has to be passed as a list []
    has_many(:citizens, Citizens)

    # buildable schema
    for buildable <- MayorGame.City.Buildable.buildables_list() do
      field(buildable, :integer)
    end

    timestamps()
  end

  def regions do
    [
      "ocean",
      "mountain",
      "desert",
      "forest",
      "lake"
    ]
  end

  def climates do
    [
      "arctic",
      "tundra",
      "temperate",
      "subtropical",
      "tropical"
    ]
  end

  def resources do
    [
      "oil",
      "coal",
      "gems",
      "gold",
      "diamond",
      "stone",
      "copper",
      "iron",
      "water"
    ]
  end

  @doc false
  def changeset(%MayorGame.City.Town{} = town, attrs) do
    town
    # add a validation here to limit the types of regions
    |> cast(
      attrs,
      [
        :title,
        :pollution,
        :citizen_count,
        :treasury,
        :region,
        :climate,
        :resources,
        :user_id,
        :logs,
        :tax_rates,
        :steel,
        :missiles,
        :shields,
        :sulfur,
        :gold,
        :uranium,
        :patron
      ] ++ Buildable.buildables_list()
    )
    |> validate_required([:title, :region, :climate, :user_id])
    |> validate_length(:title, min: 1, max: 20)
    |> validate_inclusion(:region, regions())
    |> validate_inclusion(:climate, climates())
    |> unique_constraint(:title)
  end
end
