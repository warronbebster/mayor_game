defmodule MayorGame.Repo.Migrations.CreateAuthUsers do
  use Ecto.Migration

  def change do
    create table(:auth_users) do
      add :nickname, :string

      timestamps()
    end

  end
end
