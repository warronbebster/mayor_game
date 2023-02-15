defmodule MayorGame.Repo.Migrations.AddContributors do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add(:contributor, :boolean, default: false)
    end
  end
end
