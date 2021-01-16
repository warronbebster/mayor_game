defmodule MayorGame.City.Citizens do
  use Ecto.Schema
  import Ecto.Changeset

  schema "citizens" do
    field :lastMoved, :naive_datetime
    field :money, :integer
    field :name, :string
    field :city, :id

    timestamps()
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:name, :money, :lastMoved])
    |> validate_required([:name, :money, :lastMoved])
  end
end
