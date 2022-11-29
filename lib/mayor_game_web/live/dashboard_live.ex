defmodule MayorGameWeb.DashboardLive do
  # require Logger

  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  # don't need this because you get it in DashboardView?
  # use Phoenix.HTML

  alias MayorGame.City
  alias MayorGame.City.Town
  alias MayorGameWeb.DashboardView
  # alias MayorGame.Repo
  # alias Ecto.Changeset

  def render(assigns) do
    DashboardView.render("show.html", assigns)
  end

  # if user is logged in:
  def mount(_params, %{"current_user" => current_user}, socket) do
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:ok,
     socket
     |> assign(current_user: current_user |> MayorGame.Repo.preload(:town))
     |> assign_cities()}
  end

  # if user is not logged in
  def mount(_params, _session, socket) do
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:ok,
     socket
     |> assign_cities()}
  end

  def handle_info(%{event: "ping", payload: world}, socket) do
    {:noreply, socket |> assign_cities()}
  end

  # Assign all cities as the cities list. Maybe I should figure out a way to only show cities for that user.
  # at some point should sort by number of citizens
  defp assign_cities(socket) do
    cities = City.list_cities()
    world = MayorGame.Repo.get!(MayorGame.City.World, 1)

    assign(socket, :cities, cities)
    |> assign(:world, world)
  end
end
