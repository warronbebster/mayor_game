defmodule MayorGame.Repo.Migrations.AddUraniumMineso
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :uranium_mines, :integer, default: 0
    end
  end
end
