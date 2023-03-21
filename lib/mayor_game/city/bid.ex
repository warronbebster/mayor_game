defmodule MayorGame.City.Bid do
  use Ecto.Schema
  alias MayorGame.City.{Town}
  import Ecto.Changeset

  @attrs [:max_price, :resource, :amount, :town_id]
  @derive {Inspect, except: [:town]}

  schema "bids" do
    belongs_to :town, Town
    field :max_price, :integer
    field :amount, :integer
    field :resource, :string

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @attrs)
    |> unique_constraint(:markets_and_resource, name: :bids_unique)
    |> validate_number(:max_price, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
  end
end
