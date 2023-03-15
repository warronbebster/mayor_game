defmodule MayorGameWeb.WikiLive.BuildableSection do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_component
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  alias MayorGameWeb.WikiView
  alias MayorGame.City.Buildable

  def render(assigns) do
    WikiView.render("section_buildable.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> update_page()}
  end

  def update_page(socket) do
    buildables_list =
      Enum.map(Buildable.buildables_kw_list(), fn {category, buildables} ->
        {category,
         buildables
         |> Enum.map(fn {buildable_key, buildable_stats} ->
           {
             buildable_key,
             Map.from_struct(buildable_stats)
           }
         end)}
      end)

    socket
    |> assign(:buildables, buildables_list)
    |> assign(:buildable_category_descriptions, Buildable.buildable_category_descriptions())
  end

  def handle_info(_assigns, socket) do
    {:noreply, socket}
  end
end
