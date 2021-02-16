defmodule MayorGame.City.Citizens do
  use Ecto.Schema
  import Ecto.Changeset

  schema "citizens" do
    # probably can get rid of this and just rely on lastUpdated in the DB
    field :money, :integer
    field :name, :string
    field :age, :integer
    field :education, :integer
    field :job, :integer
    field :has_car, :boolean
    field :last_moved, :integer
    # set citizens to belong to Info schema
    # uses foreign key (in this case, :info_id is automatically inferred)
    belongs_to :info, MayorGame.City.Info

    timestamps()
  end

  def attributes do
    [
      :money,
      :name,
      :age,
      :education,
      :has_car,
      :last_moved
    ]
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:info_id | attributes()])
    |> validate_required([:info_id | attributes()])
  end
end
