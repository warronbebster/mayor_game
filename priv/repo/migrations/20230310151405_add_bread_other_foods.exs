defmodule MayorGame.Repo.Migrations.AddBreadOtherFoods do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :bread, :integer, default: 0
      add :grapes, :integer, default: 0
      add :desalination_plants, :integer, default: 0
    end

    create constraint("cities", :bread_must_be_positive, check: "bread >= 0")
    create constraint("cities", :grapes_must_be_positive, check: "grapes >= 0")

    create constraint("cities", :desalination_plants_must_be_positive,
             check: "desalination_plants >= 0"
           )
  end
end
