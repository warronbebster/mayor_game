defmodule MayorGame.City.OngoingSanctions do
  use Ecto.Schema
  alias MayorGame.City.Town

  @attrs [:sanctioning, :sanctioned]

  schema "sanctions" do
    belongs_to :sanctioning, Town
    belongs_to :sanctioned, Town
    # field :sanctioning_id, :id
    # field :sanctioned_id, :id
    timestamps()
  end

  # def changeset(struct, params \\ %{}) do
  #   struct
  #   |> Ecto.Changeset.cast(params, [:sanction_count])
  # end
end
