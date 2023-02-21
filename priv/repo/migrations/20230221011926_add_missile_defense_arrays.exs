defmodule MayorGame.Repo.Migrations.AddMissileDefenseArrays do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :missile_defense_arrays, :integer, default: 0
    end
  end
end
