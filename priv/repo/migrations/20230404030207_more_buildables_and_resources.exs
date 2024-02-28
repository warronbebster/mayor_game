defmodule MayorGame.Repo.Migrations.MoreBuildablesAndResources do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :wineries, :integer, default: 0
      add :breweries, :integer, default: 0
      add :bars, :integer, default: 0
      add :galleries, :integer, default: 0
      add :gas_stations, :integer, default: 0

      # resources
      add :wine, :integer, default: 0
      add :coal, :integer, default: 0
      add :beer, :integer, default: 0
    end

    create constraint("cities", :wineries_must_be_positive, check: "wineries >= 0")
    create constraint("cities", :breweries_must_be_positive, check: "breweries >= 0")
    create constraint("cities", :bars_must_be_positive, check: "bars >= 0")
    create constraint("cities", :galleries_must_be_positive, check: "galleries >= 0")
    create constraint("cities", :gas_stations_must_be_positive, check: "gas_stations >= 0")
    create constraint("cities", :wine_must_be_positive, check: "wine >= 0")
    create constraint("cities", :coal_must_be_positive, check: "coal >= 0")
    create constraint("cities", :beer_must_be_positive, check: "beer >= 0")
  end
end
