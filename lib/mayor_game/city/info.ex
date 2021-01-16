defmodule MayorGame.City.Info do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cities" do
    field :region, :string
    field :title, :string
    field :user_id, :id

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
