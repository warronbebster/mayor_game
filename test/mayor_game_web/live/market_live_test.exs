defmodule MayorGameWeb.MarketLiveTest do
  use MayorGameWeb.ConnCase
  import Phoenix.LiveViewTest
  import MayorGame.Fixtures
  alias MayorGame.{Market, Repo}

  setup do
    town = town_fixture()
    {:ok, market} = Market.create_market(%{resource: "wood", town_id: town.id, min_price: 50, amount_to_sell: 5})
    %{market: market}
  end

  test "visitors can't change or remove someone else's market", %{conn: conn, market: market} do
    before = Repo.reload!(market)
    {:ok, view, _html} = live(conn, "/market")
    id = to_string(market.id)

    render_click(view, "toggle_market", %{"market_id" => id})
    render_click(view, "update_min_price", %{"market_id" => id, "value" => "1"})
    render_click(view, "update_amount_to_sell", %{"market_id" => id, "value" => "100000"})
    render_click(view, "remove_market", %{"market_id" => id})

    assert Repo.reload!(market) == before
  end
end
