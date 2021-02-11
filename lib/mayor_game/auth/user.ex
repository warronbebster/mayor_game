defmodule MayorGame.Auth.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  import Ecto.Changeset

  schema "auth_users" do
    pow_user_fields()

    field :nickname, :string
    # it's got one city
    has_many :info, MayorGame.City.Info

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> cast(attrs, [:nickname])
    |> validate_required([:nickname])
    |> validate_length(:nickname, min: 1, max: 20)
    |> unique_constraint(:nickname)
  end
end
