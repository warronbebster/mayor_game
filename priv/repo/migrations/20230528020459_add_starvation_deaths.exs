defmodule MayorGame.Repo.Migrations.AddStarvationDeaths do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :logs_deaths_starvation, :integer, default: 0
    end
  end
end
