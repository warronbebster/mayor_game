defmodule MayorGame.City.Town do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Details}

  @timestamps_opts [type: :utc_datetime]

  # don't print these on inspect
  @derive {Inspect, except: [:logs, :citizens, :detail]}

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
          logs: list,
          tax_rates: map,
          user: %MayorGame.Auth.User{},
          citizens: list,
          detail: Details.t()
        }

  schema "cities" do
    field :title, :string
    field :region, :string
    field :climate, :string
    field :resources, :map
    # this corresponds to an elixir list
    field :logs, {:array, :string}
    field :tax_rates, :map
    belongs_to :user, MayorGame.Auth.User

    # outline relationship between city and citizens
    # this has to be passed as a list []
    has_many :citizens, Citizens
    has_one :detail, Details

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
  def changeset(town, attrs) do
    town
    # add a validation here to limit the types of regions
    |> cast(attrs, [:title, :region, :climate, :resources, :user_id, :logs, :tax_rates])
    |> validate_required([:title, :region, :climate, :resources, :user_id])
    |> validate_length(:title, min: 1, max: 20)
    |> validate_inclusion(:region, regions())
    |> validate_inclusion(:climate, climates())
    |> unique_constraint(:title)
  end
end
