defmodule MayorGame.City.Citizens do
  use Ecto.Schema
  import Ecto.Changeset

  schema "citizens" do
    # probably can get rid of this and just rely on lastUpdated in the DB
    field :money, :integer
    field :name, :string
    # set citizens to belong to Info schema
    belongs_to :info, MayorGame.City.Info

    timestamps()
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:name, :money])
    |> validate_required([:name, :money])
  end
end
