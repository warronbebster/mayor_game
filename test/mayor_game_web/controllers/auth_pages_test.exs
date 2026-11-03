defmodule MayorGameWeb.AuthPagesTest do
  use MayorGameWeb.ConnCase

  test "the sign-up page uses our template, with a nickname field", %{conn: conn} do
    html = conn |> get("/registration/new") |> html_response(200)
    assert html =~ "user[nickname]"
  end

  test "the sign-in page renders", %{conn: conn} do
    assert conn |> get("/session/new") |> html_response(200) =~ "user[password]"
  end
end
