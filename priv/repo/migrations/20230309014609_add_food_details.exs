ridefmodule MayorGame.Repo.Migrations.AddFoodDetails do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      # food prod
      add :bakeries, :integer, default: 0
      add :sushi_restaurants, :integer, default: 0
      add :farmers_markets, :integer, default: 0
      add :delis, :integer, default: 0
      add :grocery_stores, :integer, default: 0
      add :butchers, :integer, default: 0

      # farming
      add :rice_farms, :integer, default: 0
      add :wheat_farms, :integer, default: 0
      add :produce_farms, :integer, default: 0
      add :livestock_farms, :integer, default: 0
      add :vineyards, :integer, default: 0

      # resources
      add :rice, :integer, default: 0
      add :wheat, :integer, default: 0
      add :produce, :integer, default: 0
      add :cows, :integer, default: 0
      add :meat, :integer, default: 0
      add :food, :integer, default: 0
    end

    create constraint("cities", :bakeries_must_be_positive, check: "bakeries >= 0")

    create constraint("cities", :sushi_restaurants_must_be_positive,
             check: "sushi_restaurants >= 0"
           )

    create constraint("cities", :farmers_markets_must_be_positive, check: "farmers_markets >= 0")

    create constraint("cities", :delis_must_be_positive, check: "delis >= 0")

    create constraint("cities", :grocery_stores_must_be_positive, check: "grocery_stores >= 0")

    create constraint("cities", :butchers_must_be_positive, check: "butchers >= 0")
    create constraint("cities", :rice_farms_must_be_positive, check: "rice_farms >= 0")
    create constraint("cities", :wheat_farms_must_be_positive, check: "wheat_farms >= 0")

    create constraint("cities", :produce_farms_must_be_positive, check: "produce_farms >= 0")

    create constraint("cities", :livestock_farms_must_be_positive, check: "livestock_farms >= 0")

    create constraint("cities", :vineyards_must_be_positive, check: "vineyards >= 0")
    create constraint("cities", :rice_must_be_positive, check: "rice >= 0")
    create constraint("cities", :wheat_must_be_positive, check: "wheat >= 0")
    create constraint("cities", :produce_must_be_positive, check: "produce >= 0")
    create constraint("cities", :cows_must_be_positive, check: "cows >= 0")
    create constraint("cities", :meat_must_be_positive, check: "meat >= 0")
    create constraint("cities", :food_must_be_positive, check: "food >= 0")
  end
end
