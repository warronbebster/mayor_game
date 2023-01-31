defmodule MayorGame.Repo.Migrations.AddSulfurGoldUranium do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :shields, :integer, default: 0
    end
  end
end
