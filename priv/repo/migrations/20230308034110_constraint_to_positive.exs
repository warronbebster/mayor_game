defmodule MayorGame.Repo.Migrations.ConstraintToPositive do
  use Ecto.Migration

  def change do
    create constraint("cities", :treasury_must_be_positive, check: "treasury > 0")
  end
end
