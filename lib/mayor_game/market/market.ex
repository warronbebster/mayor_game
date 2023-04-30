defmodule MayorGame.City.Market do
  use Ecto.Schema
  alias MayorGame.City.Town
  import Ecto.Changeset

  @attrs [:resource, :min_price, :amount_to_sell, :sell_excess, :town_id]
  @derive {Inspect, except: [:town]}

  schema "markets" do
    belongs_to :town, Town

    field :resource, :string
    field :min_price, :integer
    field :amount_to_sell, :integer
    field :sell_excess, :boolean
    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @attrs)
    |> validate_required([:town_id])
    |> validate_number(:min_price, greater_than: 0)
    |> validate_number(:amount_to_sell, greater_than: 0)
  end
end
