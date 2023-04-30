defmodule MayorGame.Repo.Migrations.AddSanctions do
  use Ecto.Migration

  def change do
    create table(:sanctions) do
      add :sanctioning_id, :id
      add :sanctioned_id, :id
      timestamps()
    end

    create index(:sanctions, [:sanctioning_id])
    create index(:sanctions, [:sanctioned_id])
    create(unique_index(:sanctions, [:sanctioning_id, :sanctioned_id]))
  end
end
