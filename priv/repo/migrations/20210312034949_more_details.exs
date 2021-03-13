defmodule MayorGame.Repo.Migrations.MoreDetails do
  use Ecto.Migration

  def change do
    alter table(:details) do
      add :middle_schools, :integer, default: 0
      add :high_schools, :integer, default: 0
      add :retail_shops, :integer, default: 0
      add :bike_lanes, :integer, default: 0
      add :bikeshare_stations, :integer, default: 0
      add :doctor_offices, :integer, default: 0
      add :hospitals, :integer, default: 0
    end
  end
end
