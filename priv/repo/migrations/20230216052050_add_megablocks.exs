defmodule MayorGame.Repo.Migrations.AddMegablocks do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :megablocks, :integer, default: 0
    end
  end
end
