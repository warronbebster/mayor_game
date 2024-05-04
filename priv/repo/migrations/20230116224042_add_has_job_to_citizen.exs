defmodule MayorGame.Repo.Migrations.AddHasJobToCitizen do
  use Ecto.Migration

  def change do
    alter table(:citizens) do
      add :has_job, :boolean, default: false
    end
  end
end
