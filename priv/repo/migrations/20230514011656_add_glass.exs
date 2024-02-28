defmodule MayorGame.Repo.Migrations.AddGlass do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :sand, :integer, default: 0
      add :glass, :integer, default: 0
    end

    create constraint("cities", :sand_must_be_positive, check: "sand >= 0")
    create constraint("cities", :glass_must_be_positive, check: "glass >= 0")
  end
end
