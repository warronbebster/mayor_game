defmodule MayorGame.City.Citizens do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "citizens" do
    field :money, :integer
    field :name, :string
    field :age, :integer
    field :education, :integer
    field :job, :integer
    field :has_car, :boolean
    # probably can get rid of this and just rely on lastUpdated in the DB
    field :last_moved, :integer
    field :preferences, :map
    # set citizens to belong to Town schema
    # uses foreign key (in this case, :town_id is automatically inferred)
    belongs_to :town, MayorGame.City.Town

    timestamps()
  end

  def attributes do
    [
      :money,
      :name,
      :age,
      :education,
      :has_car,
      :last_moved,
      :preferences
    ]
  end

  def decision_factors do
    [
      :tax_rates,
      :sprawl,
      :pollution
    ]
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:town_id | attributes()])
    |> validate_required([:town_id | attributes()])
  end
end
