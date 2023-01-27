defmodule MayorGame.Repo.Migrations.RemoveUpgradesFromBuildables do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    for buildable <- buildables_list() do
      alter table(buildable) do
        remove :upgrades
      end
    end
  end
end
