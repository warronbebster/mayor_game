defmodule MayorGame.Repo.Migrations.AddBuildablesCountToTown do
  use Ecto.Migration
  require MayorGame.Repo.Migrations.RemoveReasonFromBuildables

  @buildables_list MayorGame.Repo.Migrations.RemoveReasonFromBuildables.buildables_list() ++
                     [:air_bases, :mines, :defense_bases]
  defmacro buildables_list, do: @buildables_list

  def change do
    for buildable <- @buildables_list do
      alter table(:cities) do
        add(buildable, :integer, default: 0)
      end
    end
  end
end
