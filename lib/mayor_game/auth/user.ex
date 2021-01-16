defmodule MayorGame.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "auth_users" do
    field :nickname, :string
    has_one :info, MayorGame.City.Info

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:nickname])
    |> validate_required([:nickname])
    |> unique_constraint(:nickname)
  end
end
