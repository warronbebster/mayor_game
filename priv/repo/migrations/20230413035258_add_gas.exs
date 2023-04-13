defmodule MayorGame.Repo.Migrations.AddGas do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :gas, :integer, default: 0
    end

    create constraint("cities", :gas_must_be_positive, check: "gas >= 0")
  end
end
