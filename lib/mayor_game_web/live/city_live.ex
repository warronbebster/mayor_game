defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}

  alias MayorGameWeb.CityView

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  # mount/2 is the callback that runs right at the beginning of LiveView's lifecycle,
  # wiring up socket assigns necessary for rendering the view.
  def mount(_assigns, socket) do
    {:ok, socket}
  end

  # this handles different events
  # this one in particular handles "add_citizen"
  # do "events" only come from the .leex front-end?
  def handle_event(
        "add_citizen",
        %{"message" => %{"content" => content}},
        # pull these assigns out of the socket?
        %{assigns: %{info_id: info_id, user_id: user_id, user: user}} = socket
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
        MayorGameWeb.Endpoint.broadcast!(
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
  def handle_info(%{event: "ping", payload: ping}, socket) do
    {:noreply, socket |> assign(:ping, ping)}
  end

  # handle_info recieves broadcasts. in this case, a broadcast with name "updated_citizens"
  # probably need to make another one of these for recieving updates from the system that
  # moves citizens around, eventually. like "citizenArrives" and "citizenLeaves"
  def handle_info(%{event: "updated_citizens", payload: updated_citizens}, socket) do
    # add updated citizens to existing socket assigns
    updated_citizens = socket.assigns[:citizens] ++ [updated_citizens]

    # then return to socket with the citizens to the socket under :citizens
    {:noreply, socket |> assign(:citizens, updated_citizens)}
  end

  # handle_params/3 runs after mount; somehow grabs the info from url?
  # pattern matches the parameters; ignores _uri, then assigns params to socket
  def handle_params(%{"info_id" => info_id, "user_id" => user_id}, _uri, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    # this is the BACKEND process that runs this particular liveview subscribing to this BACKEND pubsub
    # perhaps each city should have its own channel? and then the other backend systems can broadcast to it?
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:noreply,
     socket
     # put the user_id in assigns
     |> assign(:user_id, user_id)
     # assign ping
     |> assign(:ping, 0)
     # put the info_id in assigns
     |> assign(:info_id, info_id)
     # run helper function to get the stuff from the DB for those things
     |> assign_records()}
  end

  # takes an assign with user_id and info_id
  defp assign_records(%{assigns: %{user_id: user_id, info_id: info_id}} = socket) do
    user = Auth.get_user!(user_id)

    city =
      City.get_info!(info_id)
      |> Repo.preload([:detail, :citizens])

    socket
    |> assign(:user, user)
    |> assign(:city, city)
    |> assign(:citizens, city.citizens)
    |> assign(:detail, city.detail)
  end
end
