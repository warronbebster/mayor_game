defmodule MayorGameWeb.WikiLive.IntroSection do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_component
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  alias MayorGameWeb.WikiView
  alias MayorGame.City.Buildable

  def render(assigns) do
    WikiView.render("section_intro.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_info(_assigns, socket) do
    {:noreply, socket}
  end
end
