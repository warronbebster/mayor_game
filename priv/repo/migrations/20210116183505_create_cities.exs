defmodule MayorGame.Repo.Migrations.CreateCities do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :title, :string, null: false
      add :region, :string
      add :user_id, references(:auth_users, on_delete: :nothing), null: false

      timestamps()
    end

    #ok here in Cities i'm making an index with user_id… do I need to do this in the others?
    create index(:cities, [:user_id])
    create unique_index(:cities, [:title]) #make city names unique
  end

end
