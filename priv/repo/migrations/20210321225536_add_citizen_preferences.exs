defmodule MayorGame.Repo.Migrations.AddCitizenPreferences do
  use Ecto.Migration

  alias MayorGame.City.Citizens


  def change do
    random_preferences = Map.new(Citizens.decision_factors, fn x -> {x, :rand.uniform() |> Float.round(2) } end)

    alter table(:citizens) do
      add :preferences, :map, default: random_preferences
    end
  end
end
