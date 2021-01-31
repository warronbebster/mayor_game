defmodule MayorGame.Repo.Migrations.AddDetails do
  use Ecto.Migration

  def change do
    alter table(:details) do
      add :parks, :integer, default: 0
      add :libraries, :integer, default: 0
      add :universities, :integer, default: 0
      add :airports, :integer, default: 0
      add :office_buildings, :integer, default: 0
      add :city_treasury, :integer, default: 500
    end

  end
end
