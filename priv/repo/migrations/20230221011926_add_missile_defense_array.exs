defmodule MayorGame.Repo.Migrations.AddMissileDefenseArray do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :missile_defense_array, :integer, default: 0
    end
  end
end
