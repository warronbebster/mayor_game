defmodule MayorGame.Repo.Migrations.CreateAuthUsers do
  use Ecto.Migration

  def change do
    create table(:auth_users) do
      add :nickname, :string, null: false

      timestamps()
    end

    create unique_index(:auth_users, [:nickname]) #make usernames unique
  end
end
