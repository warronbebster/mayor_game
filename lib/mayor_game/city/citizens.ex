defmodule MayorGame.City.Citizens do
  use Ecto.Schema
  import Ecto.Changeset

  schema "citizens" do
    # probably can get rid of this and just rely on lastUpdated in the DB
    field :money, :integer
    field :name, :string
    # set citizens to belong to Info schema
    # uses foreign key (in this case, :info_id is automatically inferred)
    belongs_to :info, MayorGame.City.Info

    timestamps()
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:name, :money, :info_id])
    |> validate_required([:name, :money, :info_id])
  end
end
