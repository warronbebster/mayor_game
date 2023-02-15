defmodule MayorGame.Repo.Migrations.FusionReactors do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :fusion_reactors, :integer, default: 0
    end
  end
end
