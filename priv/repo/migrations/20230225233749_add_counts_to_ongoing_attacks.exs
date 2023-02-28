defmodule MayorGame.Repo.Migrations.AddCountsToOngoingAttacks do
  use Ecto.Migration

  def change do
    alter table(:ongoing_attacks) do
      add :attack_count, :integer, default: 1
    end
  end
end
