defmodule MayorGame.Repo.Migrations.AddNewResources do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :stone, :integer, default: 0
      add :wood, :integer, default: 0
      add :fish, :integer, default: 0
      add :oil, :integer, default: 0
      add :lithium, :integer, default: 0
      add :salt, :integer, default: 0
      add :water, :integer, default: 0
    end
  end
end
