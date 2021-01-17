defmodule MayorGame.City.Info do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Details}

  schema "cities" do
    field :region, :string
    field :title, :string
    belongs_to :user, MayorGame.Auth.User

    # outline relationship between city and citizens
    # this has to be passed as a list []
    has_many :citizens, Citizens
    has_one :detail, Details

    timestamps()
  end

  @doc false
  def changeset(info, attrs) do
    info
    # add a validation here to limit the types of regions
    |> cast(attrs, [:title, :region, :user_id])
    |> validate_required([:title, :region, :user_id])
    |> unique_constraint(:title)
  end
end
