defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache
  # alias MayorGameWeb.Pow.Routes

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  def mount(%{"title" => title}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    # this is the BACKEND process that runs this particular liveview subscribing to this BACKEND pubsub
    # perhaps each city should have its own channel? and then the other backend systems can broadcast to it?
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {
      :ok,
      socket
      # put the title in assigns
      |> assign(:title, title)
      # assign ping
      |> assign(:ping, 0)
      |> grab_city_by_title()
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
        %{assigns: %{info_id: info_id}} = socket
      ) do
    case City.create_citizens(%{
           info_id: info_id,
           name: content,
           money: 5
         }) do
      # pattern match to assign new_citizen to what's returned from City.create_citizens
      {:ok, updated_citizens} ->
        # send a message to channel cityPubSub with updatedCitizens
        # so technically here I could also send to "addlog" function or whatever?
        MayorGameWeb.Endpoint.local_broadcast(
          "cityPubSub",
          "updated_citizens",
          updated_citizens
        )

      {:error, err} ->
        Logger.error(inspect(err))
    end

    {:noreply, socket}
  end

  # huh, so this is what gets the message from Mover
  # when it gets ping, it updates just ping
  def handle_info(%{event: "ping", payload: ping}, socket) do
    {:noreply, socket |> assign(:ping, ping)}
  end

  # I think i can get away with it with the basic "update_info" function… but need to look into constraints

  # handle_info recieves broadcasts. in this case, a broadcast with name "updated_citizens"
  # probably need to make another one of these for recieving updates from the system that
  # moves citizens around, eventually. like "citizenArrives" and "citizenLeaves"

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # jk just update the whole city
    {:noreply, socket |> grab_city_by_title()}
  end

  defp grab_city_by_title(%{assigns: %{title: title}} = socket) do
    city =
      City.get_info_by_title!(title)
      |> Repo.preload([:detail, :citizens])

    # grab whole user struct
    user = Auth.get_user!(city.user_id)

    socket
    |> assign(:user_id, user.id)
    |> assign(:username, user.nickname)
    |> assign(:city, city)
  end

  # POW AUTH STUFF DOWN HERE BAYBEE

  def assign_auth(socket, session) do
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
