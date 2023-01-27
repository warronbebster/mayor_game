defmodule MayorGame.Repo.Migrations.RemoveUpgradesFromBuildables do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    for buildable <- buildables_list() do
      alter table(buildable) do
        remove :reason
        remove :enabled
      end
    end
  end
end
