defmodule MayorGame.City.World do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @typedoc """
      this makes a type for %World{} that's callable with MayorGame.City.World.t()
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          day: integer,
          pollution: integer,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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
