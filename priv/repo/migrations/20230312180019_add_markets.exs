defmodule MayorGame.Repo.Migrations.AddMarkets do
  use Ecto.Migration

  def change do
    create table(:markets) do
      add :resource, :string, null: false
      add :min_price, :integer, default: 5
      add :amount_to_sell, :integer, default: 0
      add :town_id, references(:cities), null: false
      timestamps()
    end

    create constraint("markets", :min_price_must_be_positive, check: "min_price >= 0")
    create constraint("markets", :amount_to_sell_must_be_positive, check: "amount_to_sell >= 0")

    create table(:bids) do
      add :resource, :string, null: false
      add :town_id, references(:cities), null: false
      add :max_price, :integer, default: 10
      timestamps()
    end

    create constraint("bids", :max_price_must_be_positive, check: "max_price >= 0")
    create unique_index(:bids, [:resource, :town_id], name: :bids_unique_per_city)
  end
end
