defmodule MayorGame.Repo.Migrations.AddGardens do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :gardens, :integer, default: 0
    end

    create constraint("cities", :gardens_must_be_positive, check: "gardens >= 0")
  end
end
