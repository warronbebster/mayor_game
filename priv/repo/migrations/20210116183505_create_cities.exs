defmodule MayorGame.Repo.Migrations.CreateCities do
  use Ecto.Migration

  @timestamps_opts [type: :utc_datetime]

  def resources do
    [
      "oil",
      "coal",
      "gems",
      "gold",
      "diamond",
      "stone",
      "copper",
      "iron",
      "water"
    ]
  end

  def change do
    create table(:cities) do
      add :title, :string, null: false
      add :region, :string
      add :climate, :string
      add :resources, :map, default: Map.new(resources(), fn x -> {x, 0} end)

      add :logs, {:array, :string}, default: ["City created"]

      add :tax_rates, :map,
        # whoops, there's no job level 6
        default: %{0 => 0.5, 1 => 0.5, 2 => 0.5, 3 => 0.5, 4 => 0.5, 5 => 0.5, 6 => 0.5}

      add :user_id, references(:auth_users, on_delete: :nothing)

      timestamps()
    end

    # ok here in Cities i'm making an index with user_id… do I need to do this in the others?
    create unique_index(:cities, [:user_id])
    # make city names unique
    create unique_index(:cities, [:title])
  end
end
