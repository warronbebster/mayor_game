defmodule MayorGame.Repo.Migrations.OngoingAttacksToIds do
  use Ecto.Migration

  def change do
    alter table(:ongoing_attacks) do
      modify :attacking_id, :id
      modify :attacked_id, :id
    end
  end
end
