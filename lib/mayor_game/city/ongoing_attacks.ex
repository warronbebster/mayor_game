defmodule MayorGame.City.OngoingAttacks do
  use Ecto.Schema
  alias MayorGame.City.Town

  @attrs [:attacking, :attacked, :attack_count]

  schema "ongoing_attacks" do
    belongs_to :attacking, Town
    belongs_to :attacked, Town
    # field :attacking_id, :id
    # field :attacked_id, :id
    field :attack_count, :integer
    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:attack_count])
  end
end
