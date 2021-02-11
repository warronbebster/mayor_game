defmodule MayorGame.Repo.Migrations.AddCityLogs do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      # this corresponds to an elixer list
      add :logs, {:array, :string}, default: ["City created","second log item"]
    end
  end
end
