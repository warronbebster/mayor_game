defmodule MayorGameWeb.DashboardLive do
  require Logger
  import Ecto.Query
  alias MayorGame.{City, Repo}
  alias MayorGame.City.{Town, World, OngoingAttacks}

  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  # don't need this because you get it in DashboardView?
  # use Phoenix.HTML

  alias MayorGameWeb.DashboardView

  def render(assigns) do
    DashboardView.render("show.html", assigns)
  end

  # if user is logged in:
  def mount(_params, %{"current_user" => current_user}, socket) do
    in_dev = Application.get_env(:mayor_game, :env) == :dev
    day_margin = if in_dev, do: 20_592_000, else: 2_592_000

    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    {:ok, datetime} = DateTime.now("Etc/UTC")
    check_date = DateTime.add(datetime, -day_margin, :second) |> DateTime.to_date()

    world = Repo.get!(World, 1)
    cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)

    active_cities_count =
      from(t in Town)
      |> where([t], fragment("?::date", t.last_login) >= ^check_date)
      |> MayorGame.Repo.aggregate(:count, :id)

    page_length = 50

    {:ok,
     socket
     |> assign(current_user: current_user |> Repo.preload(:town))
     |> assign(city_count: cities_count)
     |> assign(active_cities_count: active_cities_count)
     |> assign(today: datetime)
     |> assign(check_date: check_date)
     |> assign(page: 0)
     |> assign(page_length: page_length)
     |> assign(sort_direction: :desc)
     |> assign(sort_by: :citizen_count)
     |> assign(:world, world)
     |> assign(:cities, get_towns(0, check_date))
     |> assign_totals()
     |> assign_attacks()}
  end

  # if user is not logged in
  def mount(_params, _session, socket) do
    in_dev = Application.get_env(:mayor_game, :env) == :dev
    day_margin = if in_dev, do: 20_592_000, else: 2_592_000

    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    {:ok, datetime} = DateTime.now("Etc/UTC")
    check_date = DateTime.add(datetime, -day_margin, :second) |> DateTime.to_date()

    world = Repo.get!(World, 1)
    cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)

    active_cities_count =
      from(t in Town)
      |> where([t], fragment("?::date", t.last_login) >= ^check_date)
      |> MayorGame.Repo.aggregate(:count, :id)

    page_length = 50

    {:ok,
     socket
     |> assign(city_count: cities_count)
     |> assign(active_cities_count: active_cities_count)
     |> assign(today: datetime)
     |> assign(check_date: check_date)
     |> assign(page: 0)
     |> assign(page_length: page_length)
     |> assign(sort_direction: :desc)
     |> assign(sort_by: :citizen_count)
     |> assign(:world, world)
     |> assign(:cities, get_towns(0, check_date, page_length))
     |> assign_totals()
     |> assign_attacks()}
  end

  def handle_info(%{event: "ping", payload: world}, socket) do
    if Map.has_key?(socket.assigns, :current_user) do
      {:noreply,
       socket
       |> assign(
         current_user:
           MayorGame.Auth.get_user!(socket.assigns.current_user.id)
           |> Repo.preload(:town)
       )
       |> assign_totals()
       |> assign_attacks()
       |> assign(:world, world)}
    else
      {:noreply,
       socket
       |> assign_totals()
       |> assign_attacks()
       |> assign(:world, world)}
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
       |> refresh_cities()
       |> assign_totals()}
    else
      {:noreply,
       socket
       |> refresh_cities()
       |> assign_totals()}
    end
  end

  # this handles different events
  def handle_event("add_citizen", %{"city_id" => city_id}, socket) do
    if socket.assigns.current_user.id == 1 do
      town = City.get_town!(city_id)
      City.add_citizens(town, socket.assigns.world.day)
    end

    {:noreply, socket |> refresh_cities()}
  end

  def handle_event(
        "load_more",
        _value,
        socket
      ) do
    %{
      page: page,
      page_length: page_length,
      cities: cities,
      sort_by: sort_by,
      sort_direction: sort_direction,
      today: today,
      check_date: check_date
    } = socket.assigns

    next_page = page + 1

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:cities, cities ++ get_towns(next_page, check_date, page_length, sort_by, sort_direction))}
  end

  # sort events
  # no need to call assign_cities as the city list has already been retrieved
  def handle_event("sort_by_name", _value, socket) do
    {:noreply,
     socket
     |> assign(:sort_by, :title)
     |> refresh_cities()}
  end

  def handle_event("sort_by_age", _value, socket) do
    {:noreply,
     socket
     |> assign(:sort_by, :id)
     |> refresh_cities()}
  end

  def handle_event("sort_by_population", _value, socket) do
    {:noreply,
     socket
     |> assign(:sort_by, :citizen_count)
     |> refresh_cities()}
  end

  def handle_event(
        "sort_by_pollution",
        _value,
        socket
      ) do
    {:noreply,
     socket
     |> assign(:sort_by, :pollution)
     |> refresh_cities()}
  end

  def handle_event(
        "switch_order",
        _value,
        socket
      ) do
    direction = if socket.assigns.sort_direction == :desc, do: :asc, else: :desc

    {:noreply,
     socket
     |> assign(:sort_direction, direction)
     |> refresh_cities()}
  end

  # Sort cities here
  # defp sort_cities(socket) do
  #   sorted_cities =
  #     if Map.has_key?(socket.assigns, :sort),
  #       do:
  #         (case socket.assigns.sort do
  #            "name" ->
  #              socket.assigns.cities |> Enum.sort_by(&(&1.title |> String.downcase()), :asc)

  #            "pollution" ->
  #              socket.assigns.cities |> Enum.sort_by(& &1.pollution, :desc)

  #            "age" ->
  #              socket.assigns.cities |> Enum.sort_by(& &1.id, :desc)

  #            _ ->
  #              socket.assigns.cities |> Enum.sort_by(& &1.citizen_count, :desc)
  #          end),
  #       else: socket.assigns.cities |> Enum.sort_by(& &1.citizen_count, :desc)

  #   socket
  #   |> assign(:cities, sorted_cities)
  # end

  defp refresh_cities(socket) do
    %{
      page: page,
      page_length: page_length,
      sort_by: sort_by,
      sort_direction: sort_direction,
      today: today,
      check_date: check_date
    } = socket.assigns

    all_cities_recent = get_towns(0, check_date, (page + 1) * page_length, sort_by, sort_direction)

    # use sort_cities to sort
    #  |> Enum.sort_by(& &1.citizen_count, :desc)

    socket
    |> assign(:cities, all_cities_recent)
  end

  defp assign_totals(socket) do
    date = socket.assigns.today
    check_date = socket.assigns.check_date

    query =
      from(t in Town)
      |> where([t], fragment("?::date", t.last_login) >= ^check_date)

    pollution_sum = Repo.aggregate(query, :sum, :pollution)
    citizens_sum = Repo.aggregate(query, :sum, :citizen_count)

    socket
    |> assign(:pollution_sum, pollution_sum)
    |> assign(:citizens_sum, citizens_sum)
  end

  defp assign_attacks(socket) do
    # cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)
    attacks =
      Repo.all(OngoingAttacks)
      |> Repo.preload([:attacking, :attacked])

    socket
    |> assign(:attacks, attacks)
  end

  def get_towns(page, check_date, per_page \\ 50, sort_field \\ :citizen_count, direction \\ :desc) do
    # {:ok, datetime} = NaiveDateTime.new(check_date, ~T[00:00:00])

    # eventually can move this to pull out of assigns for effeciency

    # conditions = dynamic([q], Date.diff(t.last_login, datetime) <= -30)

    from(t in Town)
    |> where([t], fragment("?::date", t.last_login) >= ^check_date)
    # ok this looks to be working
    |> select([:citizen_count, :pollution, :id, :user_id, :title, :patron, :contributor, :last_login])
    |> paginate(page, per_page)
    |> order_by([{^direction, ^sort_field}])
    |> Repo.all()
    |> Repo.preload([:user])
  end

  def paginate(query, page, per_page) do
    offset_by = per_page * page

    query
    |> limit(^per_page)
    |> offset(^offset_by)
  end
end
