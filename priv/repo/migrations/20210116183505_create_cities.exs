defmodule MayorGame.Repo.Migrations.CreateCities do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :title, :string
      add :region, :string
      add :user_id, references(:auth_users, on_delete: :nothing)

      timestamps()
    end

    create index(:cities, [:user_id])
    create unique_index(:cities, [:title]) #make city names unique
  end

end
