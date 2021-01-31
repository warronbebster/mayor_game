defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :roads, :integer, default: 0
      add :schools, :integer, default: 0
      add :houses, :integer, default: 0
      add :info_id, references(:cities, on_delete: :nothing)

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
