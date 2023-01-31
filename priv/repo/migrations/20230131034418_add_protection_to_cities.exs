defmodule MayorGame.Repo.Migrations.AddProtectionToCities do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :shields, :integer, default: 0
    end
  end
end
