defmodule MayorGame.Repo.Migrations.AddPatreonLevels do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add(:patron, :integer, default: 0)
    end
  end
end
