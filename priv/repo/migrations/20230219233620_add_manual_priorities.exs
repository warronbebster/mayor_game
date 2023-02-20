defmodule MayorGame.Repo.Migrations.AddManualPriorities do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    alter table(:cities) do
      add :priorities, :map, default: buildables_default_priorities()
    end
  end
end
