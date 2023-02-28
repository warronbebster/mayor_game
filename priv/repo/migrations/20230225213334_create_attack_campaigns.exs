defmodule MayorGame.Repo.Migrations.CreateAttackCampaigns do
  use Ecto.Migration

  def change do
    create table(:ongoing_attacks) do
      add :attacking_id, references(:cities)
      add :attacked_id, references(:cities)
      timestamps()
    end

    create index(:ongoing_attacks, [:attacking_id])
    create index(:ongoing_attacks, [:attacked_id])
  end
end
