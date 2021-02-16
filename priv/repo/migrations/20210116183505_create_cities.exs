defmodule MayorGame.Repo.Migrations.CreateCities do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :title, :string, null: false
      add :region, :string
      add :logs, {:array, :string}, default: ["City created","second log item"]
      # add :treasury, :integer, default: 500
      add :user_id, references(:auth_users, on_delete: :nothing)

      timestamps()
    end

    # ok here in Cities i'm making an index with user_id… do I need to do this in the others?
    create index(:cities, [:user_id])
    # make city names unique
    create unique_index(:cities, [:title])
  end
end
