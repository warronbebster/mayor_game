defmodule MayorGameWeb.WikiLive.ResourceSection do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_component
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  alias MayorGameWeb.WikiView
  alias MayorGame.City.Resource

  def render(assigns) do
    WikiView.render("section_resource.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> update_page()}
  end

  def update_page(socket) do
    resources_list =
      Enum.map(Resource.resources_kw_list(), fn {category, resources} ->
        {category,
         resources
         |> Enum.map(fn {resource_key, resource_stats} ->
           {
             resource_key,
             Map.from_struct(resource_stats)
           }
         end)}
      end)

    socket
    |> assign(:resources, resources_list)
    |> assign(:resource_category_descriptions, Resource.resource_category_descriptions())
  end

  def handle_info(_assigns, socket) do
    {:noreply, socket}
  end
end
