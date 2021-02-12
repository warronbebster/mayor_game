defmodule MayorGame.Repo.Migrations.AddTransit do
  use Ecto.Migration

  def change do
    alter table(:details) do
      # this corresponds to an elixer list
      add :apartments, :integer, default: 0

    end
  end
end
