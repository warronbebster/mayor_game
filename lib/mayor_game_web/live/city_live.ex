defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache
  alias MayorGameWeb.Pow.Routes

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  # mount/2 is the callback that runs right at the beginning of LiveView's lifecycle,
  # wiring up socket assigns necessary for rendering the view.
  # def mount(_assigns, socket) do
  #   {:ok, socket}
  # end

  def mount(%{"info_id" => info_id, "user_id" => user_id}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    # this is the BACKEND process that runs this particular liveview subscribing to this BACKEND pubsub
    # perhaps each city should have its own channel? and then the other backend systems can broadcast to it?

    IO.puts("SESSION PRINT:")
    IO.inspect(session)
    # gotta pull info out of mayor_game_auth here

    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:ok,
     socket
     # put the user_id in assigns
     |> assign(:user_id, user_id)
     # put the info_id in assigns
     |> assign(:info_id, info_id)
     # assign ping
     |> assign(:ping, 0)
     |> assign_auth(session)

     # run helper function to get the stuff from the DB for those things
     |> grab_city_from_db()}
  end

  # handle_params/3 runs after mount; somehow grabs the info from url?
  # pattern matches the parameters; ignores _uri, then assigns params to socket
  # def handle_params(%{"info_id" => info_id, "user_id" => user_id}, _uri, socket) do
  #   # subscribe to the channel "cityPubSub". everyone subscribes to this channel
  #   # this is the BACKEND process that runs this particular liveview subscribing to this BACKEND pubsub
  #   # perhaps each city should have its own channel? and then the other backend systems can broadcast to it?

  #   MayorGameWeb.Endpoint.subscribe("cityPubSub")

  #   {:noreply,
  #    socket
  #    # put the user_id in assigns
  #    |> assign(:user_id, user_id)
  #    # put the info_id in assigns
  #    |> assign(:info_id, info_id)
  #    # assign ping
  #    |> assign(:ping, 0)

  #    # run helper function to get the stuff from the DB for those things
  #    |> grab_city_from_db()}
  # end

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

  # I think i can get away  with it with the basic "update_info" function… but need to look into constraints

  # handle_info recieves broadcasts. in this case, a broadcast with name "updated_citizens"
  # probably need to make another one of these for recieving updates from the system that
  # moves citizens around, eventually. like "citizenArrives" and "citizenLeaves"
  def handle_info(_assigns, socket) do
    # def handle_info(%{event: "updated_citizens", payload: updated_citizens}, socket) do
    # add updated citizens to existing socket assigns
    # ok so right now this only updates the assigns for citizens
    # but can it do it for the whole city struct?
    # updated_citizens = socket.assigns[:citizens] ++ [updated_citizens]
    # then return to socket with the citizens to the socket under :citizens
    # {:noreply, socket |> assign(:citizens, updated_citizens)}

    # jk just update the whole city
    {:noreply, socket |> grab_city_from_db()}
  end

  # takes an assign with user_id and info_id
  defp grab_city_from_db(%{assigns: %{user_id: user_id, info_id: info_id}} = socket) do
    # grab whole user struct
    user = Auth.get_user!(user_id)

    # grab city from DB
    city =
      City.get_info!(info_id)
      |> Repo.preload([:detail, :citizens])

    socket
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
        socket.assigns.user_id == to_string(socket.assigns.current_user.id)
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
