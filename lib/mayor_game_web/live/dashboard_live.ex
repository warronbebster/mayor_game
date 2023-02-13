defmodule MayorGameWeb.DashboardLive do
  require Logger
  import Ecto.Query
  alias MayorGame.City.{Town}
  alias MayorGame.Repo

  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  # don't need this because you get it in DashboardView?
  # use Phoenix.HTML

  alias MayorGameWeb.DashboardView

  def render(assigns) do
    DashboardView.render("show.html", assigns)
  end

  # if user is logged in:
  def mount(_params, %{"current_user" => current_user}, socket) do
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:ok,
     socket
     |> assign(current_user: current_user |> Repo.preload(:town))
     |> assign_cities()}
  end

  # if user is not logged in
  def mount(_params, _session, socket) do
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:ok,
     socket
     |> assign_cities()}
  end

  def handle_info(%{event: "ping", payload: _world}, socket) do
    if Map.has_key?(socket.assigns, :current_user) do
      {:noreply,
       socket
       |> assign(
         current_user:
           MayorGame.Auth.get_user!(socket.assigns.current_user.id)
           |> Repo.preload(:town)
       )
       |> assign_cities()}
    else
      {:noreply,
       socket
       |> assign_cities()}
    end
  end

  def handle_info(%{event: "pong", payload: _world}, socket) do
    if Map.has_key?(socket.assigns, :current_user) do
      {:noreply,
       socket
       |> assign(
         current_user:
           MayorGame.Auth.get_user!(socket.assigns.current_user.id)
           |> Repo.preload(:town)
       )
       |> assign_cities()}
    else
      {:noreply,
       socket
       |> assign_cities()}
    end
  end

  # this handles different events
  def handle_event(
        "add_citizen",
        %{"name" => content, "userid" => user_id, "city_id" => city_id},
        # pull these variables out of the socket
        assigns = socket
      ) do
    # IO.inspect(get_user(socket, session))

    if socket.assigns.current_user.id == 1 do
      new_citizen = %{
        town_id: city_id,
        age: 0,
        education: 0,
        has_job: false,
        last_moved: socket.assigns.world.day,
        preferences: :rand.uniform(6)
      }

      from(t in Town,
        where: t.id == ^city_id,
        update: [
          push: [
            citizens_blob: ^new_citizen
          ]
        ]
      )
      |> Repo.update_all([])
    end

    {:noreply, socket |> assign_cities()}
  end

  # sort events
  def handle_event(
        "sort_by_name",
        _value,
        assigns = socket
      ) do
    {:noreply,
     socket
     |> assign(:sort, "name")
     |> assign_cities()}
  end

  def handle_event(
        "sort_by_age",
        _value,
        assigns = socket
      ) do
    {:noreply,
     socket
     |> assign(:sort, "age")
     |> assign_cities()}
  end

  def handle_event(
        "sort_by_population",
        _value,
        assigns = socket
      ) do
    {:noreply,
     socket
     |> assign(:sort, "population")
     |> assign_cities()}
  end

  def handle_event(
        "sort_by_pollution",
        _value,
        assigns = socket
      ) do
    {:noreply,
     socket
     |> assign(:sort, "pollution")
     |> assign_cities()}
  end

  # Assign all cities as the cities list. Maybe I should figure out a way to only show cities for that user.
  # at some point should sort by number of citizens
  defp assign_cities(socket) do
    # cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)
    all_cities_recent =
      from(t in Town, select: [:citizen_count, :pollution, :id, :title, :user_id, :patron])
      |> MayorGame.Repo.all()
      |> MayorGame.Repo.preload(:user)
      |> Enum.sort_by(& &1.citizen_count, :desc)

    all_cities_recent =
      if Map.has_key?(socket.assigns, :sort),
        do:
          (case socket.assigns.sort do
             "name" ->
               all_cities_recent |> Enum.sort_by(&(&1.title |> String.downcase()), :asc)

             "pollution" ->
               all_cities_recent |> Enum.sort_by(& &1.pollution, :desc)

             "age" ->
               all_cities_recent |> Enum.sort_by(& &1.id, :desc)

             _ ->
               all_cities_recent |> Enum.sort_by(& &1.citizen_count, :desc)
           end),
        else: all_cities_recent |> Enum.sort_by(& &1.citizen_count, :desc)

    pollution_sum = Enum.sum(Enum.map(all_cities_recent, fn city -> city.pollution end))
    citizens_sum = Enum.sum(Enum.map(all_cities_recent, fn city -> city.citizen_count end))

    world = MayorGame.Repo.get!(MayorGame.City.World, 1)

    socket
    |> assign(:cities, all_cities_recent)
    |> assign(:world, world)
    |> assign(:pollution_sum, pollution_sum)
    |> assign(:citizens_sum, citizens_sum)
  end
end
