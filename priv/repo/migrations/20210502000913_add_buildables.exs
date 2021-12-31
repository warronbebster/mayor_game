defmodule MayorGame.Repo.Migrations.AddBuildables do
  use Ecto.Migration
  import MayorGame.City.Buildable

  @timestamps_opts [type: :utc_datetime]

  def change do
    for buildable <- buildables_list() do
      create table(buildable) do
        add :enabled, :boolean, default: true
        add :reason, {:array, :string}, default: []
        add :upgrades, {:array, :string}, default: []

        add :details_id, references(:details)

        timestamps()
      end

      create index(buildable, [:details_id])
    end
  end
end
