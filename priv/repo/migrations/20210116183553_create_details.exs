defmodule MayorGame.Repo.Migrations.CreateDetails do
  use Ecto.Migration

  def change do
    create table(:details) do
      add :roads, :integer
      add :schools, :integer
      add :houses, :integer
      add :info_id, references(:cities, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:details, [:info_id])
  end
end
