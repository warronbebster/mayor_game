defmodule MayorGame.Repo.Migrations.MoreStorageBuildings do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :cow_pens, :integer, default: 0
      add :silos, :integer, default: 0
      add :refrigerated_warehouses, :integer, default: 0
    end

    create constraint("cities", :cow_pens_must_be_positive, check: "cow_pens >= 0")
    create constraint("cities", :silos_must_be_positive, check: "silos >= 0")

    create constraint("cities", :refrigerated_warehouses_must_be_positive,
             check: "refrigerated_warehouses >= 0"
           )
  end
end
