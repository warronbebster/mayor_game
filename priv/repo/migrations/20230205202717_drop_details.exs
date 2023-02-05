defmodule MayorGame.Repo.Migrations.DropDetails do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    for buildable <- buildables_list() do
      drop(table(buildable))
    end

    drop(table(:details))
  end
end
