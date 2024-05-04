defmodule MayorGame.Repo.Migrations.AddMissilesToTowns do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :missiles, :integer, default: 0
    end
  end
end
