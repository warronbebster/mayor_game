# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}
  import MayorGame.CityHelpers
  alias MayorGame.City.Buildable

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache
  # alias MayorGameWeb.Pow.Routes

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  def mount(%{"title" => title}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    world = Repo.get!(MayorGame.City.World, 1)

    {
      :ok,
      socket
      # put the title and day in assigns
      |> assign(:title, title)
      |> assign(:world, world)
      |> update_city_by_title()
      |> assign_auth(session)
      # run helper function to get the stuff from the DB for those things
    }
  end

  # this handles different events
  def handle_event(
        "add_citizen",
        %{"message" => %{"content" => content}},
        # pull these variables out of the socket
        %{assigns: %{city: city}} = socket
      ) do
    case City.create_citizens(%{
           town_id: city.id,
           name: content,
           money: 5,
           education: Enum.random([0, 1, 2, 3, 4]),
           age: 0,
           has_car: false,
           last_moved: 0
         }) do
      # pattern match to assign new_citizen to what's returned from City.create_citizens
      {:ok, _updated_citizens} ->
        IO.puts("updated 1 citizen")

      {:error, err} ->
        Logger.error(inspect(err))
    end

    {:noreply, socket |> update_city_by_title()}
  end

  # event
  def handle_event("gib_money", _value, %{assigns: %{city: city}} = socket) do
    case City.update_details(city.detail, %{city_treasury: city.detail.city_treasury + 1000}) do
      {:ok, _updated_town} ->
        IO.puts("money gabe")

      {:error, err} ->
        Logger.error(inspect(err))
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "purchase_building",
        %{"building" => building_to_buy, "category" => building_category},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?

    building_to_buy_atom = String.to_existing_atom(building_to_buy)
    building_category_atom = String.to_existing_atom(building_category)

    # get price — don't want to set price on front-end for cheating reasons
    purchase_price =
      get_in(Buildable.buildables(), [building_category_atom, building_to_buy_atom, :price])

    # check for upgrade requirements?

    case City.purchase_buildable(city.detail, building_to_buy_atom, purchase_price) do
      {:ok, _updated_detail} ->
        IO.puts("purchase success")

      {:error, err} ->
        Logger.error(inspect(err))
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "demolish_building",
        %{"building" => building_to_demolish, "buildable_id" => buildable_id},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?

    case City.demolish_buildable(city.detail, building_to_demolish, buildable_id) do
      {:ok, _updated_detail} ->
        IO.puts("demolition success")

      {:error, err} ->
        Logger.error(inspect(err))
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "buy_upgrade",
        %{
          "building" => buildable_to_upgrade,
          "buildable_id" => buildable_id,
          "upgrade" => upgrade_name,
          "upgrade_cost" => upgrade_cost,
          "value" => _value
        },
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?

    buildable_to_upgrade_atom =
      if is_atom(buildable_to_upgrade),
        do: buildable_to_upgrade,
        else: String.to_existing_atom(buildable_to_upgrade)

    buildable_to_upgrade =
      Repo.get_by!(Ecto.assoc(city.detail, buildable_to_upgrade_atom), id: buildable_id)

    # TODO: remove console prints
    IO.inspect(buildable_to_upgrade)

    case City.update_buildable(city.detail, buildable_to_upgrade_atom, buildable_id, %{
           # updates the upgrades map in the specific buildable
           upgrades: [to_string(upgrade_name) | buildable_to_upgrade.upgrades]
         }) do
      {:ok, _updated_detail} ->
        IO.puts("buildable upgraded successfully")

        # then charges from the treasury
        City.update_details(city.detail, %{
          city_treasury: city.detail.city_treasury - String.to_integer(upgrade_cost)
        })

      {:error, err} ->
        Logger.error(inspect(err))

      nil ->
        IO.puts('wat nil')
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "update_tax_rates",
        %{"job_level" => job_level, "value" => updated_value},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?
    updated_value_float = Float.parse(updated_value)

    if updated_value_float != :error do
      updated_value_constrained =
        elem(updated_value_float, 0) |> max(0.0) |> min(1.0) |> Float.round(2)

      IO.puts(to_string(updated_value_constrained))

      # check if it's below 0 or above 1 or not a number

      updated_tax_rates = city.tax_rates |> Map.put(job_level, updated_value_constrained)

      case City.update_town(city, %{tax_rates: updated_tax_rates}) do
        {:ok, _updated_detail} ->
          IO.puts("tax rates updated")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  # this is what gets messages from CityCalculator
  def handle_info(%{event: "ping", payload: world}, socket) do
    {:noreply, socket |> assign(:world, world) |> update_city_by_title()}
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # just update the whole city
    {:noreply, socket |> update_city_by_title()}
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_city_by_title(%{assigns: %{title: title, world: world}} = socket) do
    city =
      City.get_town_by_title!(title)
      |> preload_city_check()

    # grab whole user struct
    user = Auth.get_user!(city.user_id)

    reset_buildables_to_enabled(city)

    # take buildable list, put something in each one, buildable_status
    city_baked_details = %{city | detail: bake_details(city.detail)}

    city_updated =
      city_baked_details
      |> calculate_area()
      |> calculate_energy(world)
      |> calculate_money()

    # have to have this separate from the actual city because the city might not have some buildables, but they're still purchasable
    buildables_with_status = calculate_buildables_statuses(city_updated)

    socket
    |> assign(:buildables, buildables_with_status)
    |> assign(:user_id, user.id)
    |> assign(:username, user.nickname)
    |> assign(:city, city_updated)
  end

  # this takes the generic buildables map and builds the status (enabled, etc) for each buildable
  defp calculate_buildables_statuses(city) do
    Enum.map(Buildable.buildables(), fn {category, buildables} ->
      {category,
       buildables
       |> Enum.map(fn {buildable_key, buildable_stats} ->
         {buildable_key, Map.from_struct(calculate_buildable_status(buildable_stats, city))}
       end)}
    end)
  end

  # this takes a buildable metadata, and builds status from database
  # TODO: Clean this shit upppp
  defp calculate_buildable_status(buildable, city_with_stats) do
    if city_with_stats.detail.city_treasury > buildable.price do
      cond do
        # enough energy AND enough area

        buildable.energy_required != nil and
          city_with_stats.available_energy >= buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.available_area >= buildable.area_required) ->
          %{buildable | purchasable: true, purchasable_reason: "valid"}

        # not enough energy, enough area
        buildable.energy_required != nil and
          city_with_stats.available_energy < buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.available_area >= buildable.area_required) ->
          %{buildable | purchasable: false, purchasable_reason: "not enough energy to build"}

        # enough energy, not enough area
        buildable.energy_required != nil and
          city_with_stats.available_energy >= buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.available_area < buildable.area_required) ->
          %{buildable | purchasable: false, purchasable_reason: "not enough area to build"}

        # not enough energy AND not enough area
        buildable.energy_required != nil and
          city_with_stats.available_energy < buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.available_area < buildable.area_required) ->
          %{
            buildable
            | purchasable: false,
              purchasable_reason: "not enough area or energy to build"
          }

        # no energy needed, enough area
        buildable.energy_required == nil &&
            (buildable.area_required != nil and
               city_with_stats.available_area >= buildable.area_required) ->
          %{buildable | purchasable: true, purchasable_reason: "valid"}

        # no energy needed, not enough area
        buildable.energy_required == nil &&
            (buildable.area_required != nil and
               city_with_stats.available_area < buildable.area_required) ->
          %{buildable | purchasable: false, purchasable_reason: "not enough area to build"}

        # no area needed, enough energy
        buildable.area_required == nil &&
            (buildable.energy_required != nil and
               city_with_stats.available_energy >= buildable.energy_required) ->
          %{buildable | purchasable: true, purchasable_reason: "valid"}

        # no area needed, not enough energy
        buildable.area_required == nil &&
            (buildable.energy_required != nil and
               city_with_stats.available_energy < buildable.energy_required) ->
          %{buildable | purchasable: false, purchasable_reason: "not enough energy to build"}

        # no area needed, no energy needed
        buildable.energy_required == nil and buildable.area_required == nil ->
          %{buildable | purchasable: true, purchasable_reason: "valid"}

        # catch-all
        true ->
          %{buildable | purchasable: true, purchasable_reason: "valid"}
      end
    else
      %{buildable | purchasable: false, purchasable_reason: "not enough money"}
    end
  end

  # POW
  # AUTH
  # POW AUTH STUFF DOWN HERE BAYBEE

  defp assign_auth(socket, session) do
    # add an assign :current_user to the socket
    socket = assign_new(socket, :current_user, fn -> get_user(socket, session) end)

    if socket.assigns.current_user do
      # if there's a user logged in
      socket
      |> assign(
        :is_user_mayor,
        to_string(socket.assigns.user_id) == to_string(socket.assigns.current_user.id)
      )
    else
      # if there's no user logged in
      socket
      |> assign(:is_user_mayor, false)
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
           CredentialsCache.get([backend: Pow.Store.Backend.MnesiaCache], token) do
      user
    else
      _any -> nil
    end
  end

  defp get_user(_, _, _), do: nil
end
