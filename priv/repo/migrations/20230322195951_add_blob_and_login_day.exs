defmodule MayorGame.Repo.Migrations.AddBlobAndLoginDay do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add(:citizens_compressed, :map, default: %{})
      add(:last_login, :date, default: fragment("CURRENT_DATE"))
    end
  end
end
