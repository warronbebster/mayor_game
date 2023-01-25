defmodule MayorGame.Repo.Migrations.RemovePollutionTreasuryFromDetails do
  use Ecto.Migration

  def change do
    alter table(:details) do
      remove :pollution
      remove :city_treasury
    end
  end
end
