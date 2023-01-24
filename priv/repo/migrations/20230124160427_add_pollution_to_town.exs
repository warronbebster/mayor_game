defmodule MayorGame.Repo.Migrations.AddPollutionToTown do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :pollution, :integer, default: 0
      add :treasury, :integer, default: 0
    end
  end
end
