defmodule MayorGame.City.Citizens do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  @typedoc """
      type for %Citizens{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          money: integer,
          name: String.t(),
          age: integer,
          education: integer,
          job: integer,
          has_car: boolean,
          last_moved: integer,
          preferences: map,
          town: map
        }

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
