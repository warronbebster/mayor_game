defmodule MayorGameWeb.BuildableTooltip do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_component
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  alias MayorGameWeb.WikiView
  alias MayorGame.City.{Buildable, Resource}

  def render(assigns) do
    WikiView.render("tooltip_buildable.html", assigns)
  end

  def mount(_params, %{"building_type" => building_type}, socket) do
    {:ok,
     socket
     |> assign(building_type: building_type)
     |> update_page()}
  end

  def update_page(socket) do
    building_stats = Buildable.buildables_flat()[socket.assigns.building_type]

    socket
    |> assign(building_stats: building_stats)
    |> assign(:resources_flat, Resource.resources_flat())
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    {:noreply, socket}
  end
end
