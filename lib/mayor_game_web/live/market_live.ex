# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.MarketLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.City.{Town}
  alias MayorGame.{City, Repo, Rules, Market, Bid}

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
    world = Repo.get!(MayorGame.City.World, 1)
    in_dev = Application.get_env(:mayor_game, :env) == :dev

    resource_types = [
      {:sulfur, "orange-700"},
      {:uranium, "violet-700"},
      {:steel, "slate-700"},
      {:fish, "cyan-700"},
      {:oil, "stone-700"},
      {:stone, "slate-700"},
      {:bread, "amber-800"},
      {:wheat, "amber-600"},
      {:grapes, "indigo-700"},
      {:wood, "amber-700"},
      {:food, "yellow-700"},
      {:produce, "green-700"},
      {:meat, "red-700"},
      {:rice, "yellow-700"},
      {:cows, "stone-700"},
      {:lithium, "lime-700"},
      {:water, "sky-700"},
      {:salt, "zinc-700"},
      {:missiles, "red-700"},
      {:shields, "blue-700"}
    ]

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
  def handle_event(
        "add_market",
        %{"resource" => resource},
        # pull these variables out of the socket
        %{assigns: %{current_user: current_user}} = socket
      ) do
    IO.inspect(current_user.town)
    IO.inspect(Repo.preload(current_user.town, [:markets]))

    IO.inspect(
      Market.create_market(%{resource: resource, town_id: current_user.town.id, min_price: 5, amount_to_sell: 1})
    )

    {:noreply, socket |> get_markets_and_bids() |> update_current_user()}
  end

  def handle_event("toggle_market", %{"market_id" => market_id}, %{assigns: %{current_user: _current_user}} = socket) do
    market = Market.get_market(market_id)

    Market.update_market(market, %{sell_excess: !market.sell_excess})

    {:noreply, socket |> get_markets_and_bids()}
  end

  def handle_event(
        "remove_market",
        %{"market_id" => market_id},
        # pull these variables out of the socket
        %{assigns: %{current_user: current_user}} = socket
      ) do
    from(m in City.Market, where: m.id == ^market_id)
    |> Repo.delete_all([])

    {:noreply, socket |> get_markets_and_bids()}
  end

  def handle_event(
        "update_amount_to_sell",
        %{"market_id" => market_id, "value" => updated_value},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    # IO.inspect(market)
    updated_value_int = Integer.parse(updated_value)

    if updated_value_int != :error do
      updated_value_constrained = elem(updated_value_int, 0) |> max(1)

      # if socket.assigns.current_user.id == city.user_id do
      # check if user is mayor here?
      from(m in City.Market,
        where: m.id == ^market_id,
        update: [
          set: [
            amount_to_sell: ^updated_value_constrained
          ]
        ]
      )
      |> Repo.update_all([])

      {:noreply, socket |> get_markets_and_bids()}
    end
  end

  def handle_event(
        "update_min_price",
        %{"market_id" => market_id, "value" => updated_value},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    updated_value_int = Integer.parse(updated_value)

    if updated_value_int != :error do
      updated_value_constrained = elem(updated_value_int, 0) |> max(1)

      from(m in City.Market,
        where: m.id == ^market_id,
        update: [
          set: [
            min_price: ^updated_value_constrained
          ]
        ]
      )
      |> Repo.update_all([])

      {:noreply, socket |> get_markets_and_bids()}
    end
  end

  # ————————————————————————————————————————————————————————————————————————————————————————
  # BID CONTROLS ————————————————————————————————————————————————————————————————————————————————————————
  # ————————————————————————————————————————————————————————————————————————————————————————
  def handle_event(
        "add_bid",
        %{"resource" => resource},
        # pull these variables out of the socket
        %{assigns: %{current_user: current_user}} = socket
      ) do
    Bid.create_bid(%{resource: resource, town_id: current_user.town.id, max_price: 5})

    {:noreply, socket |> get_markets_and_bids() |> update_current_user()}
  end

  def handle_event(
        "update_max_price",
        %{"bid_id" => bid_id, "value" => updated_value},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    # IO.inspect(market)
    updated_value_int = Integer.parse(updated_value)

    bid = Bid.get_bid(bid_id)

    if updated_value_int != :error && current_user.town.id == bid.town_id do
      updated_value_constrained = elem(updated_value_int, 0) |> max(1)

      Bid.update_bid(bid, %{max_price: updated_value_constrained})

      {:noreply, socket |> get_markets_and_bids()}
    end
  end

  def handle_event(
        "update_amount_to_buy",
        %{"bid_id" => bid_id, "value" => updated_value},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    updated_value_int = Integer.parse(updated_value)

    bid = Bid.get_bid(bid_id)

    if updated_value_int != :error && current_user.town.id == bid.town_id do
      updated_value_constrained = elem(updated_value_int, 0) |> max(1)

      Bid.update_bid(bid, %{amount: updated_value_constrained})

      {:noreply, socket |> get_markets_and_bids()}
    end
  end

  def handle_event(
        "remove_bid",
        %{"bid_id" => bid_id},
        # pull these variables out of the socket
        %{assigns: %{current_user: current_user}} = socket
      ) do
    bid = Bid.get_bid(bid_id)

    if current_user.town.id == bid.town_id do
      Bid.delete_bid(bid)
    end

    {:noreply, socket |> get_markets_and_bids()}
  end

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
    # just update the whole city
    markets_by_resource = Enum.group_by(Market.list_markets(), & &1.resource)
    bids_by_resource = Enum.group_by(Bid.list_bids(), & &1.resource)

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

      socket |> assign(:is_user_admin, is_user_admin)
    else
      # if there's no user logged in
      socket |> assign(:is_user_admin, false)
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
