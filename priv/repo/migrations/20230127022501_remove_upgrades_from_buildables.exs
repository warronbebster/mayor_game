defmodule MayorGame.Repo.Migrations.RemoveUpgradesFromBuildables do
  use Ecto.Migration

  require MayorGame.Repo.Migrations.AddBuildables

  @buildables_list MayorGame.Repo.Migrations.AddBuildables.buildables_list()
  defmacro buildables_list, do: @buildables_list

  def change do
    for buildable <- @buildables_list do
      alter table(buildable) do
        remove(:upgrades)
      end
    end
  end
end
