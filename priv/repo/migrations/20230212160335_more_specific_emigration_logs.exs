defmodule MayorGame.Repo.Migrations.MoreSpecificEmigrationLogs do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      remove :logs_emigration
      add :logs_emigration_housing, :map, default: %{}
      add :logs_emigration_taxes, :map, default: %{}
      add :logs_emigration_jobs, :map, default: %{}
    end
  end
end
