# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.LogsLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.{City, Repo, Rules, CityHelpers}
  alias MayorGame.City.{Buildable, ResourceStatistics}

  import Ecto.Query, warn: false

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache

  def render(assigns) do
    # use CityView view to render city/city.html.leex template with assigns
    CityView.render("logs.html", assigns)
  end

  def mount(%{"title" => title}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel

    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    world = Repo.get!(MayorGame.City.World, 1)
    in_dev = Application.get_env(:mayor_game, :env) == :dev

    resource_types = ResourceStatistics.resource_kw_list()

    subtotal_types =
      ([
         {:health, "rose-700"},
         {:area, "cyan-700"},
         {:housing, "amber-700"},
         {:energy, "yellow-700"},
         {:culture, "blue-700"},
         {:sprawl, "yellow-700"},
         {:fun, "violet-700"}
       ] ++ resource_types)
      |> Enum.map(fn {k, v} -> {k, "text-" <> v} end)

    buildables_map = %{
      buildables_flat: Buildable.buildables_flat(),
      buildables: Buildable.buildables(),
      buildables_kw_list: Buildable.buildables_kw_list(),
      buildables_list: Buildable.buildables_list(),
      buildables_default_priorities: Buildable.buildables_default_priorities()
    }

    # production_categories = [:energy, :area, :housing]

    {
      :ok,
      socket
      # put the title and day in assigns
      |> assign(:title, title)
      |> assign(:world, world)
      |> assign(:in_dev, in_dev)
      # |> assign(:form, City.update_town(%Town{}))
      |> assign(:buildables_map, buildables_map)
      |> assign(:building_requirements, [
        "workers",
        "energy",
        "area",
        "money",
        "steel",
        "sulfur",
        "uranium",
        "rice",
        "meat",
        "water",
        "cows",
        "bread",
        "wheat",
        "produce",
        "salt",
        "oil",
        "beer",
        "wine",
        "grapes",
        "coal"
      ])
      |> assign(:subtotal_types, subtotal_types)
      |> assign(:resource_types, resource_types)
      |> update_city_by_title()
      |> assign_auth(session)
      |> update_current_user()
      # run helper function to get the stuff from the DB for those things
    }
  end

  # this is what gets messages from CityCalculator
  # kinda weird that it recalculates so much
  # is it possible to just send the updated contents over the wire to each city?
  def handle_info(%{event: "ping", payload: world}, socket) do
    {:noreply, socket |> assign(:world, world) |> update_city_by_title()}
  end

  # this is what gets messages from CityCalculator
  def handle_info(%{event: "pong", payload: _world}, socket) do
    {:noreply, socket |> update_city_by_title()}
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # just update the whole city
    {:noreply, socket |> update_city_by_title()}
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_city_by_title(%{assigns: %{title: title, world: world}} = socket) do
    # cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)

    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    season = Rules.season_from_day(world.day)

    # This variable shall be unmodified. This way there is no need to recast it into a struct in other handle_info instructions.
    # ok this bit is uhhh not light
    city =
      City.get_town_by_title!(title)
      |> CityHelpers.preload_city_check()

    # :eprof.start_profiling([self()])

    town_stats =
      CityHelpers.calculate_city_stats(
        city,
        world,
        pollution_ceiling,
        season,
        socket.assigns.buildables_map,
        socket.assigns.in_dev,
        false
      )

    # ok, here the price is updated per each CombinedBuildable

    # have to have this separate from the actual city because the city might not have some buildables, but they're still purchasable
    # this status is for the whole category
    # this could be much simpler
    # this is ok, just bakes

    # citizen_edu_count = town_stats.citizen_count_by_level

    socket
    |> assign(:season, season)
    |> assign(:user_id, city.user.id)
    |> assign(:username, city.user.nickname)
    # don't modify city; use it as a baseline
    |> assign(:city, city)
    # use a separate object for calculated stats
    |> assign(:city_stats, town_stats)
    |> assign(:construction_count, %{})
    |> assign(:construction_cost, 0)
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(%{assigns: %{current_user: current_user}} = socket) do
    if !is_nil(current_user) do
      current_user_updated = current_user |> Repo.preload([:town])

      if is_nil(current_user_updated.town) do
        socket
        |> assign(:current_user, current_user_updated)
      else
        updated_town = City.get_town!(current_user_updated.town.id) |> Repo.preload([:attacks_sent])

        socket
        |> assign(:current_user, Map.put(current_user_updated, :town, updated_town))
      end
    else
      socket
    end
  end

  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(socket) do
    socket
  end

  # this takes the generic buildables map and builds the status (enabled, etc) for each buildable
  defp calculate_buildables_statuses(city, world, buildables) do
    Enum.map(buildables, fn {category, buildables} ->
      {category,
       buildables
       |> Enum.map(fn {_key, buildable_stats} ->
         {buildable_stats.title,
          Map.from_struct(
            calculate_buildable_status(
              buildable_stats,
              city,
              world,
              Map.get(city, buildable_stats.title)
            )
          )}
       end)}
    end)
  end

  # this takes a buildable, and builds purchasable status from database
  # TODO: Clean this shit upppp
  # why do I even need this lol. let you build but just
  defp calculate_buildable_status(buildable, city, world, buildable_count) do
    updated_price = Rules.building_price(buildable.price, buildable_count)

    buildable
    |> Map.put(
      :actual_produces,
      MayorGame.CityHelpers.get_production_map(
        buildable.produces,
        buildable.multipliers,
        city.citizen_count,
        city.region,
        Rules.season_from_day(world.day)
      )
    )
    |> Map.put(:price, updated_price)
  end

  # POW
  # AUTH
  # POW AUTH STUFF DOWN HERE BAYBEE ——————————————————————————————————————————————————————————————————

  defp assign_auth(socket, session) do
    date = Date.utc_today()
    # add an assign :current_user to the socket
    socket =
      assign_new(socket, :current_user, fn ->
        get_user(socket, session) |> Repo.preload([:town])
      end)

    if socket.assigns.current_user do
      # if there's a user logged in
      is_user_mayor =
        if !socket.assigns.in_dev,
          do: to_string(socket.assigns.user_id) == to_string(socket.assigns.current_user.id),
          else: to_string(socket.assigns.user_id) == to_string(socket.assigns.current_user.id)

      is_user_admin =
        if !socket.assigns.in_dev,
          do: socket.assigns.current_user.id == 1,
          else: true

      is_user_verified =
        if !socket.assigns.in_dev,
          do:
            !is_nil(socket.assigns.current_user.email_confirmed_at) &&
              socket.assigns.current_user.is_alt == false,
          else: true

      # reset last_login
      if is_user_mayor do
        City.update_town(socket.assigns.city, %{last_login: date})
      end

      socket
      |> assign(:is_user_mayor, is_user_mayor)
      |> assign(:is_user_admin, is_user_admin)
      |> assign(:is_user_verified, is_user_verified)
    else
      # if there's no user logged in
      socket
      |> assign(:is_user_mayor, false)
      |> assign(:is_user_admin, false)
      |> assign(:is_user_verified, false)
    end
  end

  # POW HELPER FUNCTIONS
  defp get_user(socket, session, config \\ [otp_app: :mayor_game])

  defp get_user(socket, %{"mayor_game_auth" => signed_token}, config) do
    conn = struct!(Plug.Conn, secret_key_base: socket.endpoint.config(:secret_key_base))
    salt = Atom.to_string(Pow.Plug.Session)

    with {:ok, token} <- Pow.Plug.verify_token(conn, salt, signed_token, config),
         # Use Pow.Store.Backend.EtsCache if you haven't configured Mnesia yet.
         {user, _metadata} <-
           CredentialsCache.get([backend: Pow.Postgres.Store], token) do
      user
    else
      _any -> nil
    end
  end

  defp get_user(_, _, _), do: nil
end
