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

  test "setting your tax rates", %{conn: conn, my_town: my_town} do
    {:ok, view, _html} = live(conn, "/city/#{my_town.title}")

    render_blur(view, "update_tax_rates", %{"job_level" => "2", "value" => "0.45"})
    render_blur(view, "update_tax_rates", %{"job_level" => "3", "value" => "7"})
    render_blur(view, "update_tax_rates", %{"job_level" => "bogus", "value" => "0.5"})

    assert Repo.reload!(my_town).tax_rates == Map.merge(my_town.tax_rates, %{"2" => 0.45, "3" => 1.0})
  end

  test "setting your building priorities", %{conn: conn, my_town: my_town} do
    {:ok, view, _html} = live(conn, "/city/#{my_town.title}")

    render_blur(view, "update_priorities", %{"building_type" => "huts", "value" => "3"})
    # an unknown key would crash the game loop, which turns these keys back into atoms
    render_blur(view, "update_priorities", %{"building_type" => "not_a_building", "value" => "3"})

    priorities = Repo.reload!(my_town).priorities
    assert priorities["huts"] == 3
    refute Map.has_key?(priorities, "not_a_building")
  end

  test "you can't change someone else's taxes or priorities", %{conn: conn, their_town: their_town} do
    before = Repo.reload!(their_town)
    {:ok, view, _html} = live(conn, "/city/#{their_town.title}")

    render_blur(view, "update_tax_rates", %{"job_level" => "2", "value" => "0.99"})
    render_blur(view, "update_priorities", %{"building_type" => "huts", "value" => "50"})
    render_click(view, "toggle_retaliate", %{})

    assert Repo.reload!(their_town) == before
  end
end
