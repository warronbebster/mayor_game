defmodule MayorGame.City.World do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "world" do
    # probably can get rid of this and just rely on lastUpdated in the DB
    field :day, :integer
    field :pollution, :integer

    timestamps()
  end

  def attributes do
    [
      :day,
      :pollution
    ]
  end

  @doc false
  def changeset(world, attrs) do
    world
    |> cast(attrs, attributes())
    |> validate_required(attributes())
  end
end
