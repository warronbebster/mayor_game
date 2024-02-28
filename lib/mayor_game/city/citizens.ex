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
      :preferences
    ]
  end

  def decision_factors do
    [
      :tax_rates,
      :sprawl,
      :fun,
      :health,
      :pollution,
      :culture,
      :crime
    ]
  end

  def preset_preferences do
    # https://numbergenerator.org/randomnumbergenerator/sum-to#!numbers=7&low=1&high=100&unique=true&csv=&oddeven=&oddqty=0&sorted=false&addfilters=sum_of_numbers-val-100
    %{
      1 => %{tax_rates: 0.1, sprawl: 0.4, fun: 0.72, health: 0.2, pollution: 0.3, culture: 0.7, crime: 0.11},
      2 => %{tax_rates: 0.43, sprawl: 0.1, fun: 0.16, health: 0.5, pollution: 0.2, culture: 0.3, crime: 0.30},
      3 => %{tax_rates: 0.2, sprawl: 0.4, fun: 0.61, health: 0.9, pollution: 0.3, culture: 0.20, crime: 0.1},
      4 => %{tax_rates: 0.7, sprawl: 0.6, fun: 0.1, health: 0.2, pollution: 0.65, culture: 0.4, crime: 0.15},
      5 => %{tax_rates: 0.7, sprawl: 0.2, fun: 0.6, health: 0.27, pollution: 0.54, culture: 0.3, crime: 0.1},
      6 => %{tax_rates: 0.32, sprawl: 0.23, fun: 0.20, health: 0.19, pollution: 0.2, culture: 0.1, crime: 0.3},
      7 => %{tax_rates: 0.2, sprawl: 0.5, fun: 0.33, health: 0.43, pollution: 0.4, culture: 0.10, crime: 0.3},
      8 => %{tax_rates: 0.1, sprawl: 0.24, fun: 0.3, health: 0.5, pollution: 0.2, culture: 0.61, crime: 0.4},
      9 => %{tax_rates: 0.1, sprawl: 0.21, fun: 0.61, health: 0.5, pollution: 0.2, culture: 0.6, crime: 0.4},
      10 => %{tax_rates: 0.2, sprawl: 0.4, fun: 0.1, health: 0.3, pollution: 0.7, culture: 0.70, crime: 0.13},
      11 => %{tax_rates: 0.18, sprawl: 0.5, fun: 0.28, health: 0.26, pollution: 0.19, culture: 0.3, crime: 0.1},
      12 => %{tax_rates: 0.1, sprawl: 0.4, fun: 0.16, health: 0.6, pollution: 0.2, culture: 0.3, crime: 0.68},
      13 => %{tax_rates: 0.2, sprawl: 0.51, fun: 0.6, health: 0.3, pollution: 0.29, culture: 0.5, crime: 0.4}
    }
  end

  def compress_citizen_blob(citizens, day) do
    if citizens == [] do
      %{}
    else
      citizens
      |> Enum.map(fn citizen ->
        citizen
        |> Map.update("birthday", round100(day - citizen["age"]), & &1)
        |> Map.delete("age")
        |> Map.delete("town_id")
      end)
      |> Enum.frequencies()
      |> Enum.map(fn {k, v} -> {v, k} end)
      |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)

      # aha this is where the trouble comes in. if there's a match in
      # |> Enum.into(%{})
    end
  end

  def unfold_citizen_blob(citizen_blob, day, town_id) do
    if citizen_blob == %{} do
      []
    else
      citizen_blob
      |> Enum.map(fn {count, list_of_citizen_types} ->
        Enum.map(list_of_citizen_types, fn citizen ->
          citizen =
            citizen
            |> Map.put("town_id", town_id)
            |> Map.put("age", max(day - citizen["birthday"], 0))

          count = if is_number(count), do: count, else: String.to_integer(count)

          for _i <- 1..count do
            citizen
          end
        end)
        |> List.flatten()
      end)
      |> List.flatten()
    end
  end

  @doc false
  def changeset(citizens, attrs) do
    citizens
    |> cast(attrs, [:town_id | attributes()])
    |> validate_required([:town_id | attributes()])
  end

  def round100(n) when rem(n, 100) < 51, do: n - rem(n, 100)
  def round100(n), do: n + (100 - rem(n, 100))
end
