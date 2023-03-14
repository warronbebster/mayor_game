defmodule MayorGame.Repo.Migrations.DropCitizens do
  use Ecto.Migration

  def change do
    drop(table(:citizens))
  end
end
