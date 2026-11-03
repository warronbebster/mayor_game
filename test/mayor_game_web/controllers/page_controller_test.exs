defmodule MayorGameWeb.PageControllerTest do
  use MayorGameWeb.ConnCase

  setup do
    MayorGame.Repo.insert!(%MayorGame.City.World{id: 1, day: 0, pollution: 0}, on_conflict: :nothing)
    :ok
  end

  test "GET / shows the world dashboard", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Total Citizens"
  end
end
