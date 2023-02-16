defmodule MayorGame.Repo.Migrations.MigrateToBigint do
  use Ecto.Migration
  import MayorGame.City.Buildable

  # def change do
  #   alter table(:cities) do
  #     modify :treasury, :bigint
  #   end
  # end

  def up do
    alter table(:cities) do
      modify :treasury, :bigint, default: 0
      modify :pollution, :bigint, default: 0
      modify :shields, :bigint, default: 0
      modify :gold, :bigint, default: 0
      modify :missiles, :bigint, default: 0
      modify :uranium, :bigint, default: 0
    end
  end

  def down do
    alter table(:cities) do
      modify :treasury, :integer, default: 0
      modify :pollution, :integer, default: 0
      modify :shields, :integer, default: 0
      modify :gold, :integer, default: 0
      modify :missiles, :integer, default: 0
      modify :uranium, :integer, default: 0
    end
  end
end
