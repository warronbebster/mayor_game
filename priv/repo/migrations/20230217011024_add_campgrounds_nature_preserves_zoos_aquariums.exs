defmodule MayorGame.Repo.Migrations.AddCampgroundsNaturePreservesZoosAquariums do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :campgrounds, :integer, default: 0
      add :nature_preserves, :integer, default: 0
      add :zoos, :integer, default: 0
      add :aquariums, :integer, default: 0
    end
  end
end
