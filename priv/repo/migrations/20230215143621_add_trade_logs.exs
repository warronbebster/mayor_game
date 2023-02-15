defmodule MayorGame.Repo.Migrations.AddTradeLogs do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :logs_sent, :map, default: %{}
      add :logs_received, :map, default: %{}
    end
  end
end
