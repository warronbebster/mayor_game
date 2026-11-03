defmodule MayorGame.MarketTest do
  use MayorGame.DataCase
  import MayorGame.Fixtures
  alias MayorGame.{Bid, Market}

  test "markets and bids only accept tradable resources" do
    town = town_fixture()

    assert {:ok, _} = Market.create_market(%{resource: "wood", town_id: town.id, min_price: 5, amount_to_sell: 1})

    assert {:error, _} =
             Market.create_market(%{resource: "treasury", town_id: town.id, min_price: 5, amount_to_sell: 1})

    assert {:error, _} = Market.create_market(%{resource: "shields", town_id: town.id, min_price: 5, amount_to_sell: 1})

    assert {:ok, _} = Bid.create_bid(%{resource: "wood", town_id: town.id, max_price: 5})
    assert {:error, _} = Bid.create_bid(%{resource: "air_bases", town_id: town.id, max_price: 5})
  end
end
