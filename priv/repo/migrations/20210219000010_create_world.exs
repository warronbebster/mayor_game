defmodule MayorGame.Repo.Migrations.CreateWorld do
  use Ecto.Migration

  @timestamps_opts [type: :utc_datetime]

  def change do
    create table(:world) do
      add :day, :integer, default: 0
      add :pollution, :integer, default: 0

      timestamps()
    end
  end
end
