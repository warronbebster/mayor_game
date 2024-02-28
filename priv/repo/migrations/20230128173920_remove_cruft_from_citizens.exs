defmodule MayorGame.Repo.Migrations.RemoveCruftFromCitizens do
  use Ecto.Migration

  def change do
    alter table(:citizens) do
      remove :money
      remove :job
      remove :has_car
    end
  end
end
