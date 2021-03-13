defmodule MayorGame.City.Info do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Details}

  schema "cities" do
    field :region, :string
    field :title, :string
    # field :treasury, :integer
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
      "forest"
    ]
  end

  @doc false
  def changeset(info, attrs) do
    # regions = regions()

    info
    # add a validation here to limit the types of regions
    |> cast(attrs, [:title, :region, :user_id, :logs, :tax_rates])
    |> validate_required([:title, :region, :user_id])
    |> validate_length(:title, min: 1, max: 20)
    |> validate_inclusion(:region, regions())
    |> unique_constraint(:title)
  end
end
