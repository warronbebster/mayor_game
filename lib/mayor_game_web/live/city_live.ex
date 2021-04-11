defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}

  alias MayorGame.City.Details

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
    world = MayorGame.Repo.get!(MayorGame.City.World, 1)

    {
      :ok,
      socket
      # put the title in assigns
      |> assign(:title, title)
      |> assign(:buildables, Details.buildables())
      |> assign(:ping, world.day)
      |> update_city_by_title()
      |> assign_auth(session)
      # run helper function to get the stuff from the DB for those things
    }
  end

  # this handles different events
  # this one in particular handles "add_citizen"
  # do "events" only come from the .leex front-end?
  def handle_event(
        "add_citizen",
        %{"message" => %{"content" => content}},
        # pull these variables out of the socket
        %{assigns: %{city: city}} = socket
      ) do
    case City.create_citizens(%{
           info_id: city.id,
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
      {:ok, _updated_info} ->
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
      get_in(Details.buildables(), [building_category_atom, building_to_buy_atom, :price])

    # check for upgrade requirements?
    IO.inspect(building_to_buy_atom)
    IO.inspect(purchase_price)

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
        %{"building" => building_to_demolish, "building_id" => building_id},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?

    building_to_demolish_atom = String.to_existing_atom(building_to_demolish)

    # how many buildings are there now
    # {:ok, current_value} = Map.fetch(city.detail, building_to_demolish_atom)

    # gotta fix this so it's ID-specific
    # attrs = Map.new([{building_to_demolish_atom, tl(current_value)}])

    case City.demolish_buildable(city.detail, building_to_demolish_atom, building_id) do
      {:ok, _updated_detail} ->
        IO.puts("demolition success")

      {:error, err} ->
        Logger.error(inspect(err))
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

      case City.update_info(city, %{tax_rates: updated_tax_rates}) do
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
  def handle_info(%{event: "ping", payload: ping}, socket) do
    {:noreply, socket |> assign(:ping, ping) |> update_city_by_title()}
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # just update the whole city
    {:noreply, socket |> update_city_by_title()}
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_city_by_title(%{assigns: %{title: title, ping: ping}} = socket) do
    city =
      City.get_info_by_title!(title)
      |> Repo.preload([:detail, :citizens])

    # grab whole user struct
    user = Auth.get_user!(city.user_id)

    area = MayorGame.CityCalculator.calculate_area(city)
    energy = MayorGame.CityCalculator.calculate_energy(city, ping)
    money = MayorGame.CityCalculator.calculate_money(city)

    # figure out how to send an assign for each building type with disabled buildings
    # enum map for buildables
    # adjust some to be disabled

    buildings_status =
      Details.buildables_list()
      |> Enum.reduce(%{}, fn building_type, acc ->
        building_count = length(Map.get(city.detail, building_type))
        area_disabled_count = Enum.count(area.disabled_buildings, &(&1 == building_type))
        energy_disabled_count = Enum.count(energy.disabled_buildings, &(&1 == building_type))
        money_disabled_count = Enum.count(money.disabled_buildings, &(&1 == building_type))

        total_disabled =
          max(area_disabled_count, energy_disabled_count)
          |> max(money_disabled_count)

        # add money_disabled count here
        # somehow, i need to get to this:
        # really, the only thing that needs to be updated is the reason
        # no need to go through a crazy cond
        # if total is 0,
        # needs nothing to operate
        # otherwise check values
        reason =
          if total_disabled == 0 do
            "operational"
          else
            disabled_list =
              Enum.reduce(
                %{
                  area: area_disabled_count,
                  energy: energy_disabled_count,
                  money: money_disabled_count
                },
                [],
                fn {name, count}, acc ->
                  if count > 0,
                    do: [to_string(name) | acc],
                    else: acc
                end
              )

            "needs " <> Enum.join(disabled_list, ", ") <> " to operate"
          end

        results = %{
          disabled: total_disabled,
          enabled: building_count - total_disabled,
          reason: reason
        }

        Map.put_new(acc, building_type, results)
      end)

    socket
    |> assign(:user_id, user.id)
    |> assign(:username, user.nickname)
    |> assign(:city, city)
    |> assign(:energy, energy)
    |> assign(:area, area)
    |> assign(:buildings_status, buildings_status)
  end

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
