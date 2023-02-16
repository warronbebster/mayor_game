defmodule MayorGame.Repo.Migrations.RemoveLogs do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      remove :logs
    end
  end
end
