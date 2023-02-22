defmodule MayorGame.Repo.Migrations.MigrateToBigint do
  use Ecto.Migration

  def up do
    alter table(:world) do
      modify :pollution, :bigint, default: 0
      modify :day, :bigint, default: 0
    end
  end

  def down do
    alter table(:world) do
      modify :pollution, :integer, default: 0
      modify :day, :integer, default: 0
    end
  end
end
