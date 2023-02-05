defmodule MayorGame.Repo.Migrations.AddBuildablesCountToTown do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    for buildable <- buildables_list() do
      alter table(:cities) do
        add(buildable, :integer, default: 0)
      end
    end
  end
end
