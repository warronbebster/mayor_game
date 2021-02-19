defmodule MayorGame.City.World do
  use Ecto.Schema
  import Ecto.Changeset

  schema "world" do
    # probably can get rid of this and just rely on lastUpdated in the DB
    field :day, :integer

    timestamps()
  end

  def attributes do
    [
      :day
    ]
  end

  @doc false
  def changeset(world, attrs) do
    world
    |> cast(attrs, attributes())
    |> validate_required(attributes())
  end
end
