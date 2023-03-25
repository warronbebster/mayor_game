defmodule MayorGame.Repo.Migrations.NoMoreBlob do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      remove :citizens_blob
    end
  end
end
