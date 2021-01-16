defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset

  schema "details" do
    field :houses, :integer
    field :roads, :integer
    field :schools, :integer
    field :city, :id

    timestamps()
  end

  @doc false
  def changeset(details, attrs) do
    details
    |> cast(attrs, [:roads, :schools, :houses])
    |> validate_required([:roads, :schools, :houses])
  end
end
