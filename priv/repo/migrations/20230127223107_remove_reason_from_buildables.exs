defmodule MayorGame.Repo.Migrations.RemoveReasonFromBuildables do
  use Ecto.Migration
  require MayorGame.Repo.Migrations.RemoveUpgradesFromBuildables

  @buildables_list MayorGame.Repo.Migrations.RemoveUpgradesFromBuildables.buildables_list()
  defmacro buildables_list, do: @buildables_list

  def change do
    for buildable <- @buildables_list do
      alter table(buildable) do
        remove :reason
        remove :enabled
      end
    end
  end
end
