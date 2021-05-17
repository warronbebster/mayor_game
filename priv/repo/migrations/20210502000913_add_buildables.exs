defmodule MayorGame.Repo.Migrations.AddBuildables do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    for buildable <- buildables_list() do
      create table(buildable) do
        add :enabled, :boolean, default: true
        add :reason, {:array, :string}, default: []
        add :upgrades, :map, default: %{}

        add :details_id, references(:details)
      end

      create index(buildable, [:details_id])
    end
  end
end
