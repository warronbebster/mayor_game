defmodule MayorGameWeb.CityLive do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}

  def render(assigns) do
    ~L"""
    <div>
      <b>User name:</b> <%= @user.nickname %>
    </div>
    <div>
      <b>city title:</b> <%= @city.title %>

      <b>city region:</b> <%= @city.region %>
      <b>detail houses:</b> <%= @detail.houses %>
      <b>detail schools:</b> <%= @detail.schools %>
      <b>detail roads:</b> <%= @detail.roads %>
    </div>
    <div>
      <%= f = form_for :message, "#", [phx_submit: "update_city_name"] %>
        <%= label f, :content %>
        <%= text_input f, :content %>
        <%= submit "Send" %>
      </form>
    </div>
    <div>
      <b>citizens:</b>
      <%= for citizen <- @citizens do %>
        <div>
          <b><%= citizen.name %></b> money:: <%= citizen.money %>
        </div>
      <% end %>
    </div>
    """
  end

  # mount/2 is the callback that runs right at the beginning of LiveView's lifecycle, wiring up socket assigns necessary for rendering the view.
  def mount(_assigns, socket) do
    {:ok, socket}
  end

  def handle_event(
        "update_city_name",
        %{"message" => %{"content" => content}},
        %{assigns: %{info_id: info_id, user_id: user_id, user: user}} = socket
      ) do
    case City.create_citizens(%{
           info_id: info_id,
           name: content,
           money: 5
         }) do
      # pattern match to assign new_citizen to what's returned from City.create_citizens
      {:ok, new_citizen} ->
        # this takes new_citizen and updates the user field (which it doesn't have lol?)
        # new_citizen = %{new_citizen | user: user}
        # add citizen to assigns?
        updated_citizens = socket.assigns[:citizens] ++ [new_citizen]

        {:noreply, socket |> assign(:citizens, updated_citizens)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  # handle_params/3 runs after mount
  # pattern matches the parameters; ignores _uri, then assigns params to socket
  def handle_params(%{"info_id" => info_id, "user_id" => user_id}, _uri, socket) do
    {:noreply,
     socket
     # put the user_id in assigns
     |> assign(:user_id, user_id)
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

    # |> assign(:messages, conversation.messages)
  end
end
