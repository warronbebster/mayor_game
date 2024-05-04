defmodule MayorGame.Repo.Migrations.DropDetails do
  use Ecto.Migration

  require MayorGame.Repo.Migrations.AddBuildablesCountToTown

  @buildables_list MayorGame.Repo.Migrations.AddBuildablesCountToTown.buildables_list()
  defmacro buildables_list, do: @buildables_list

  def change do
    for buildable <- @buildables_list do
      drop(table(buildable))
    end

    drop(table(:details))
  end
end
