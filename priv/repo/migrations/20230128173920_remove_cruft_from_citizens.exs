defmodule MayorGame.Repo.Migrations.RemovePollutionTreasuryFromDetails do
  use Ecto.Migration

  def change do
    alter table(:citizens) do
      remove :money
      remove :job
      remove :has_car
    end
  end
end
