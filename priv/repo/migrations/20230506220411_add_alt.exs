defmodule MayorGame.Repo.Migrations.AddAlt do
  use Ecto.Migration

  def change do
    alter table(:auth_users) do
      add :is_alt, :boolean, default: false
    end
  end
end
