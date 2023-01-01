defmodule MayorGame.Repo.Migrations.AddPollutionToTownDb do
  use Ecto.Migration

  def change do
    alter table(:details) do
      add :pollution, :integer, default: 0
    end
  end
end
