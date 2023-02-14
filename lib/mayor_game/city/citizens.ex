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
          name: String.t(),
          age: integer,
          education: 1..5,
          has_job: boolean,
          last_moved: integer | nil,
          preferences: map,
          town: MayorGame.City.Town.t()
        }

  schema "citizens" do
    field :name, :string
    field :age, :integer
    field :education, :integer
    field :has_job, :boolean
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
      :name,
      :age,
      :education,
      :has_job,
      :last_moved,
      :preferences
    ]
  end

  def decision_factors do
    [
      :tax_rates,
      :sprawl,
      :fun,
      :health,
      :pollution
    ]
  end

  def preset_preferences do
    %{
      1 => %{tax_rates: 0.1, sprawl: 0.2, fun: 0.35, health: 0.25, pollution: 0.1},
      2 => %{tax_rates: 0.5, sprawl: 0.2, fun: 0.2, health: 0.07, pollution: 0.03},
      3 => %{tax_rates: 0.15, sprawl: 0.4, fun: 0.05, health: 0.25, pollution: 0.25},
      4 => %{tax_rates: 0.6, sprawl: 0.12, fun: 0.15, health: 0.03, pollution: 0.1},
      5 => %{tax_rates: 0.2, sprawl: 0.09, fun: 0.12, health: 0.14, pollution: 0.45},
      6 => %{tax_rates: 0.82, sprawl: 0.04, fun: 0.05, health: 0.03, pollution: 0.06},
      7 => %{tax_rates: 0.82, sprawl: 0.02, fun: 0.09, health: 0.01, pollution: 0.16},
      8 => %{tax_rates: 0.26, sprawl: 0.04, fun: 0.01, health: 0.08, pollution: 0.61},
      9 => %{tax_rates: 0.03, sprawl: 0.35, fun: 0.59, health: 0.02, pollution: 0.01},
      10 => %{tax_rates: 0.65, sprawl: 0.16, fun: 0.12, health: 0.06, pollution: 0.01}
    }
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:town_id | attributes()])
    |> validate_required([:town_id | attributes()])
  end
end
