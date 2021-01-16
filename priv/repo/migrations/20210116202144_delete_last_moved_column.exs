defmodule MayorGame.Repo.Migrations.DeleteLastMovedColumn do
  use Ecto.Migration

  def change do
    alter table(:citizens) do
      remove :lastMoved
    end
  end
end
