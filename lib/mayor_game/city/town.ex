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
      details: Details.t(),
      pollution: integer,
      treasury: integer
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Details}
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  # don't print these on inspect
  @derive {Inspect, except: [:logs, :citizens, :details]}

  @typedoc """
      Type for %Town{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t :: %__MODULE__{
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
          details: Details.t(),
          pollution: integer,
          treasury: integer,
          citizen_count: integer,
          steel: integer,
          missiles: integer,
          # protection: integer,
          sulfur: integer,
          gold: integer,
          uranium: integer
        }

  schema "cities" do
    field :title, :string
    field :region, :string
    field :climate, :string
    field :resources, :map
    field :pollution, :integer
    field :treasury, :integer
    field :citizen_count, :integer
    field :steel, :integer
    field :missiles, :integer
    # field :protection, :integer
    field :sulfur, :integer
    field :gold, :integer
    field :uranium, :integer

    # this corresponds to an elixir list
    field :logs, {:array, :string}
    field :tax_rates, :map
    belongs_to :user, MayorGame.Auth.User

    # outline relationship between city and citizens
    # this has to be passed as a list []
    has_many :citizens, Citizens
    has_one :details, Details

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
    |> cast(attrs, [
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
      # :protection,
      :sulfur,
      :gold,
      :uranium
    ])
    |> validate_required([:title, :region, :climate, :user_id])
    |> validate_length(:title, min: 1, max: 20)
    |> validate_inclusion(:region, regions())
    |> validate_inclusion(:climate, climates())
    |> unique_constraint(:title)
  end
end
