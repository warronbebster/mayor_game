defmodule MayorGame.Repo.Migrations.AddSulfurGoldUranium do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :sulfur, :integer, default: 0
      add :gold, :integer, default: 0
      add :steel, :integer, default: 0
      add :uranium, :integer, default: 0
      add :microchips, :integer, default: 0
    end
  end
end
