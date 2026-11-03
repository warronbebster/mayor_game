defmodule MayorGameWeb.CityLiveTest do
  use MayorGameWeb.ConnCase
  import Phoenix.LiveViewTest
  import MayorGame.Fixtures
  alias MayorGame.Repo
  alias MayorGame.City.Town

  setup %{conn: conn} do
    Repo.insert!(%MayorGame.City.World{id: 1, day: 0, pollution: 0}, on_conflict: :nothing)
    user = user_fixture()
    my_town = town_fixture(%{user: user, treasury: 5_000, wood: 100, air_bases: 1, missiles: 100})
    their_town = town_fixture(%{treasury: 5_000, shields: 10, defense_bases: 1})
    %{conn: log_in(conn, user), my_town: my_town, their_town: their_town}
  end

  test "a signed-in mayor sees their city", %{conn: conn, my_town: my_town} do
    {:ok, _view, html} = live(conn, "/city/#{my_town.title}")
    assert html =~ my_town.title
  end

  test "sending resources to another city", %{conn: conn, my_town: my_town, their_town: their_town} do
    {:ok, view, _html} = live(conn, "/city/#{their_town.title}")

    render_submit(view, "trade", %{"town" => %{"resource" => "wood", "amount" => "40"}})

    assert Repo.reload!(my_town).wood == 60
    assert Repo.reload!(their_town).wood == 40
  end

  test "sending only works for tradable resources", %{conn: conn, my_town: my_town, their_town: their_town} do
    {mine_before, theirs_before} = {Repo.reload!(my_town), Repo.reload!(their_town)}
    {:ok, view, _html} = live(conn, "/city/#{their_town.title}")

    # crafted events: these aren't in the form's resource list
    for field <- ["user_id", "air_bases", "citizen_count", "id"] do
      render_submit(view, "trade", %{"town" => %{"resource" => field, "amount" => "1"}})
    end

    assert Repo.reload!(my_town) == mine_before
    assert Repo.reload!(their_town) == theirs_before
  end

  test "buildings can't be attacked while shields are up", %{conn: conn, their_town: their_town} do
    {:ok, view, _html} = live(conn, "/city/#{their_town.title}")

    render_click(view, "attack_building", %{"building" => "defense_bases"})

    assert Repo.reload!(their_town).defense_bases == 1
  end

  test "buying a building in your own city", %{conn: conn, my_town: my_town} do
    {:ok, view, _html} = live(conn, "/city/#{my_town.title}")

    render_click(view, "purchase_building", %{"building" => "parks"})

    assert Repo.reload!(my_town).parks == 1
  end

  test "you can't buy buildings in someone else's city", %{conn: conn, their_town: their_town} do
    {:ok, view, _html} = live(conn, "/city/#{their_town.title}")

    render_click(view, "purchase_building", %{"building" => "parks"})

    assert Repo.reload!(their_town).parks == their_town.parks
  end
end
