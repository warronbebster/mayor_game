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
      :culture
    ]
  end

  def preset_preferences do
    %{
      1 => %{tax_rates: 0.1, sprawl: 0.2, fun: 0.30, health: 0.25, pollution: 0.1, culture: 0.05},
      2 => %{tax_rates: 0.46, sprawl: 0.2, fun: 0.2, health: 0.07, pollution: 0.03, culture: 0.04},
      3 => %{tax_rates: 0.15, sprawl: 0.4, fun: 0.05, health: 0.25, pollution: 0.14, culture: 0.11},
      4 => %{tax_rates: 0.6, sprawl: 0.12, fun: 0.15, health: 0.03, pollution: 0.1, culture: 0.11},
      5 => %{tax_rates: 0.2, sprawl: 0.09, fun: 0.10, health: 0.11, pollution: 0.45, culture: 0.05},
      6 => %{tax_rates: 0.75, sprawl: 0.04, fun: 0.05, health: 0.03, pollution: 0.06, culture: 0.7},
      7 => %{tax_rates: 0.82, sprawl: 0.02, fun: 0.09, health: 0.01, pollution: 0.11, culture: 0.5},
      8 => %{tax_rates: 0.26, sprawl: 0.04, fun: 0.01, health: 0.08, pollution: 0.52, culture: 0.9},
      9 => %{tax_rates: 0.03, sprawl: 0.23, fun: 0.59, health: 0.02, pollution: 0.01, culture: 0.12},
      10 => %{tax_rates: 0.55, sprawl: 0.16, fun: 0.12, health: 0.06, pollution: 0.01, culture: 0.10},
      11 => %{tax_rates: 0.10, sprawl: 0.14, fun: 0.12, health: 0.06, pollution: 0.03, culture: 0.55}
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
        |> Map.delete("last_moved")
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
        if is_list(list_of_citizen_types) do
          Enum.map(list_of_citizen_types, fn citizen ->
            citizen =
              citizen
              |> Map.put("town_id", town_id)
              |> Map.put("age", max(day - citizen["birthday"], 0))
              |> Map.delete("birthday")

            count = if is_number(count), do: count, else: String.to_integer(count)

            for _i <- 1..count do
              citizen
            end
          end)
          |> List.flatten()
        else
          citizen =
            list_of_citizen_types
            |> Map.put("town_id", town_id)
            |> Map.put("age", max(day - list_of_citizen_types["birthday"], 0))
            |> Map.delete("birthday")

          count = if is_number(count), do: count, else: String.to_integer(count)

          for _i <- 1..count do
            citizen
          end
        end
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
