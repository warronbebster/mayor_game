defmodule MayorGame.Repo.Migrations.AddCitizenPreferences do
  use Ecto.Migration

  alias MayorGame.City.Citizens

  def change do
    random_preferences =
      Enum.reduce(Citizens.decision_factors(), %{preference_map: %{}, room_taken: 0}, fn x, acc ->
        value =
          if x == List.last(Citizens.decision_factors()),
            do: (1 - acc.room_taken) |> Float.round(2),
            else: (:rand.uniform() * (1 - acc.room_taken)) |> Float.round(2)

        %{
          preference_map: Map.put(acc.preference_map, to_string(x), value),
          room_taken: acc.room_taken + value
        }
      end)

    alter table(:citizens) do
      add :preferences, :map, default: random_preferences.preference_map
    end
  end
end
