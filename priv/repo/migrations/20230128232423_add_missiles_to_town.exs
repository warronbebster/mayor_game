defmodule MayorGame.Repo.Migrations.AddMissilesToTown do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :missiles, :integer, default: 0
    end
  end
end
