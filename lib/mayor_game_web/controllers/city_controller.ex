defmodule MayorGameWeb.CityController do
  use MayorGameWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
