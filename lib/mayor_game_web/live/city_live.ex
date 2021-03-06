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

    case City.purchase_details(city.detail, building_to_buy_atom, purchase_price) do
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
        %{"building" => building_to_demolish},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?

    building_to_demolish_atom = String.to_existing_atom(building_to_demolish)

    # how many buildings are there now
    {:ok, current_value} = Map.fetch(city.detail, building_to_demolish_atom)

    attrs = Map.new([{building_to_demolish_atom, current_value - 1}])

    case City.update_details(city.detail, attrs) do
      {:ok, _updated_detail} ->
        IO.puts("demolition success")

      {:error, err} ->
        Logger.error(inspect(err))
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
  defp update_city_by_title(%{assigns: %{title: title}} = socket) do
    city =
      City.get_info_by_title!(title)
      |> Repo.preload([:detail, :citizens])

    # grab whole user struct
    user = Auth.get_user!(city.user_id)

    mobility = MayorGame.CityCalculator.calculate_mobility(city)
    energy = MayorGame.CityCalculator.calculate_energy(city)

    socket
    |> assign(:user_id, user.id)
    |> assign(:username, user.nickname)
    |> assign(:city, city)
    |> assign(:mobility, mobility)
    |> assign(:energy, energy)
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
