defmodule MayorGame.City.Info do
  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Citizens, Details}

  schema "cities" do
    field :region, :string
    field :title, :string
    belongs_to :user, MayorGame.Auth.User

    # outline relationship between city and citizens
    has_many :citizens, Citizens
    has_one :detail, Details

    timestamps()
  end

  @doc false
  def changeset(info, attrs) do
    info
    |> cast(attrs, [:title, :region])
    |> validate_required([:title, :region])
    |> unique_constraint(:title)
  end
end
