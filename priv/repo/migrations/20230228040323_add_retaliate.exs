defmodule MayorGame.Repo.Migrations.AddRetaliate do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :retaliate, :boolean, default: false
    end
  end
end
