defmodule MayorGame.Repo.Migrations.CreateWorld do
  use Ecto.Migration

  def change do
    create table(:world) do
      add :day, :integer, default: 0

      timestamps()
    end
  end
end
