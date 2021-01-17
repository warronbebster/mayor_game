defmodule MayorGame.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    alter table(:auth_users) do
      add :email, :string, null: false
      add :password_hash, :string
    end

    create unique_index(:auth_users, [:email])
  end
end
