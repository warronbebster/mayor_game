defmodule MayorGame.Repo.Migrations.EnsureUniqueAttacks do
  use Ecto.Migration

  def change do
    create(unique_index(:ongoing_attacks, [:attacking_id, :attacked_id]))
  end
end
