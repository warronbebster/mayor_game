defmodule MayorGame.Repo.Migrations.MoveLogsToBigInts do
  use Ecto.Migration

  def up do
    alter table(:cities) do
      modify :logs_deaths_starvation, :bigint, default: 0
      modify :logs_deaths_pollution, :bigint, default: 0
      modify :logs_deaths_age, :bigint, default: 0
      modify :logs_deaths_housing, :bigint, default: 0
      modify :logs_deaths_attacks, :bigint, default: 0
      modify :logs_births, :bigint, default: 0
    end
  end

  def down do
    alter table(:cities) do
      modify :logs_deaths_starvation, :integer, default: 0
      modify :logs_deaths_pollution, :integer, default: 0
      modify :logs_deaths_age, :integer, default: 0
      modify :logs_deaths_housing, :integer, default: 0
      modify :logs_deaths_attacks, :integer, default: 0
      modify :logs_births, :integer, default: 0
    end
  end
end
