defmodule MayorGame.Repo.Migrations.JsonSerialize do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      # add :citizens_blob, :map, default: %{}
      add :citizens_blob, {:array, :map}, default: []
    end
  end
end
