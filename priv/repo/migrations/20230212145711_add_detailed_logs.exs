defmodule MayorGame.Repo.Migrations.AddDetailedLogs do
  use Ecto.Migration

  #   move-outs by reason
  # housing
  # jobs
  # taxes
  # - key: level
  # - total count
  # - city moved to

  # move-ins
  # - key: level
  # - total count
  # - city from

  # educations per level
  # key: level
  # count

  # deaths
  # -pollution
  # -age
  # -housing

  # births

  # attacks
  # - key: shields or building
  #
  # - which city
  # count

  def change do
    alter table(:cities) do
      add :logs_emigration, :map, default: %{}
      add :logs_immigration, :map, default: %{}
      add :logs_attacks, :map, default: %{}
      add :logs_edu, :map, default: %{}
      add :logs_deaths_pollution, :integer, default: 0
      add :logs_deaths_age, :integer, default: 0
      add :logs_deaths_housing, :integer, default: 0
      add :logs_deaths_attacks, :integer, default: 0
      add :logs_births, :integer, default: 0
      remove :resources
    end
  end
end
