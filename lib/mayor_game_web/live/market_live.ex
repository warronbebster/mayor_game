# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.MarketLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.City.{ResourceStats}
  alias MayorGame.{City, Repo, Market, Bid}

  import Ecto.Query, warn: false

  alias MayorGameWeb.MarketView

  alias Pow.Store.CredentialsCache

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    MarketView.render("show.html", assigns)
  end

  def mount(%{}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    # world = Repo.get!(MayorGame.City.World, 1)
    in_dev = Application.get_env(:mayor_game, :env) == :dev

    resource_types = ResourceStats.resource_kw_list() |> Keyword.drop([:shields])

    # production_categories = [:energy, :area, :housing]

    {
      :ok,
      socket
      # put the title and day in assigns
      |> assign(:in_dev, in_dev)
      |> assign(:resource_types, resource_types)
      |> assign_auth(session)
      |> update_current_user()
      |> get_markets_and_bids()
      # run helper function to get the stuff from the DB for those things
    }
  end

  #   active_sell_list = all sell-offers <= highest bid
  # active_bid_list = all bids >= lowest sell-offer

  # if active_sell_list is shorter, match bids/sales from high-to-low, and ignore any excess bids (first image)
  # if active_bid_list is shorter, match bids/sales from low-to-high and ignore any excess sales
  # if they're equal than it doesn't matter, just match them (third image)

  # this handles different events
  # ————————————————————————————————————————————————————————————————————————————————————————
  # MARKET CONTROLS ————————————————————————————————————————————————————————————————————————————————————————
  # ————————————————————————————————————————————————————————————————————————————————————————
  def handle_event("add_market", %{"resource" => resource}, socket) do
    if socket.assigns.is_user_verified && my_town_id(socket) do
      Market.create_market(%{resource: resource, town_id: my_town_id(socket), min_price: 5, amount_to_sell: 1})
    end

    {:noreply, socket |> get_markets_and_bids() |> update_current_user()}
  end

  def handle_event("toggle_market", %{"market_id" => market_id}, socket) do
    with_own(socket, Repo.get(City.Market, market_id), fn market ->
      Market.update_market(market, %{sell_excess: !market.sell_excess})
    end)
  end

  def handle_event("remove_market", %{"market_id" => market_id}, socket) do
    with_own(socket, Repo.get(City.Market, market_id), &Repo.delete/1)
  end

  def handle_event("update_amount_to_sell", %{"market_id" => market_id, "value" => value}, socket) do
    with_own(socket, Repo.get(City.Market, market_id), fn market ->
      with {amount, _} <- Integer.parse(value), do: Market.update_market(market, %{amount_to_sell: max(amount, 1)})
    end)
  end

  def handle_event("update_min_price", %{"market_id" => market_id, "value" => value}, socket) do
    with_own(socket, Repo.get(City.Market, market_id), fn market ->
      with {price, _} <- Integer.parse(value), do: Market.update_market(market, %{min_price: max(price, 1)})
    end)
  end

  # ————————————————————————————————————————————————————————————————————————————————————————
  # BID CONTROLS ————————————————————————————————————————————————————————————————————————————————————————
  # ————————————————————————————————————————————————————————————————————————————————————————

  def handle_event("add_bid", %{"resource" => resource}, socket) do
    if socket.assigns.is_user_verified && my_town_id(socket) do
      Bid.create_bid(%{resource: resource, town_id: my_town_id(socket), max_price: 5})
    end

    {:noreply, socket |> get_markets_and_bids() |> update_current_user()}
  end

  def handle_event("update_max_price", %{"bid_id" => bid_id, "value" => value}, socket) do
    with_own(socket, Repo.get(MayorGame.Market.Bid, bid_id), fn bid ->
      with {price, _} <- Integer.parse(value), do: Bid.update_bid(bid, %{max_price: max(price, 1)})
    end)
  end

  def handle_event("update_amount_to_buy", %{"bid_id" => bid_id, "value" => value}, socket) do
    with_own(socket, Repo.get(MayorGame.Market.Bid, bid_id), fn bid ->
      with {amount, _} <- Integer.parse(value), do: Bid.update_bid(bid, %{amount: max(amount, 1)})
    end)
  end

  def handle_event("remove_bid", %{"bid_id" => bid_id}, socket) do
    with_own(socket, Repo.get(MayorGame.Market.Bid, bid_id), &Bid.delete_bid/1)
  end

  # runs `fun` on a market or bid only if it belongs to the current user's town (or they're an admin)
  defp with_own(socket, market_or_bid, fun) do
    if market_or_bid && (market_or_bid.town_id == my_town_id(socket) || socket.assigns.is_user_admin) do
      fun.(market_or_bid)
    end

    {:noreply, socket |> get_markets_and_bids()}
  end

  defp my_town_id(%{assigns: %{current_user: %{town: %{id: town_id}}}}), do: town_id
  defp my_town_id(_socket), do: nil

  # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
  # PUBSUB
  # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————

  # this is what gets messages from CityCalculator
  # kinda weird that it recalculates so much
  # is it possible to just send the updated contents over the wire to each city?
  # def handle_info(%{event: "ping", payload: _world}, socket) do
  #   {:noreply, socket |> get_markets_and_bids()}
  # end

  # this is what gets messages from CityCalculator
  # def handle_info(%{event: "pong", payload: _world}, socket) do
  #   {:noreply, socket |> get_markets_and_bids()}
  # end

  # this is just the generic handle_info if nothing else matches
  # def handle_info(_assigns, socket) do
  #   # just update the whole city
  #   {:noreply, socket |> get_markets_and_bids()}
  # end

  def get_markets_and_bids(socket) do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    # just update the whole city
    markets_by_resource = Enum.group_by(Market.list_valid_markets(datetime), & &1.resource)
    bids_by_resource = Enum.group_by(Bid.list_valid_bids(datetime), & &1.resource)

    socket
    |> assign(:markets, markets_by_resource)
    |> assign(:bids, bids_by_resource)
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(%{assigns: %{current_user: current_user}} = socket) do
    if !is_nil(current_user) do
      current_user_updated =
        current_user
        |> Repo.preload([town: [:markets, :bids]], force: true)

      socket
      |> assign(:current_user, current_user_updated)

      # end
    else
      socket
    end
  end

  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(socket) do
    socket
  end

  # TRADING —————————————————————————————————————————————————————————————————————————————————————
  # ——————————————————————————————————————————————————————————————————

  # POW
  # AUTH
  # POW AUTH STUFF DOWN HERE BAYBEE ——————————————————————————————————————————————————————————————————

  defp assign_auth(socket, session) do
    # add an assign :current_user to the socket
    socket =
      assign_new(socket, :current_user, fn ->
        get_user(socket, session) |> Repo.preload([:town])
      end)

    if socket.assigns.current_user do
      is_user_admin =
        if !socket.assigns.in_dev,
          do: socket.assigns.current_user.id == 1,
          else: true

      is_user_verified =
        if !socket.assigns.in_dev,
          do: !is_nil(socket.assigns.current_user.email_confirmed_at) && !socket.assigns.current_user.is_alt,
          else: true

      socket |> assign(is_user_admin: is_user_admin, is_user_verified: is_user_verified)
    else
      # if there's no user logged in
      socket |> assign(is_user_admin: false, is_user_verified: false)
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
