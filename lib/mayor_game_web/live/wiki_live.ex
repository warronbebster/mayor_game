# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.WikiLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.CityCalculator
  alias MayorGame.{Auth, City, Repo}
  alias MayorGame.City.Town
  # import MayorGame.CityHelpers
  alias MayorGame.City.Buildable
  alias MayorGame.City.Resource

  import Ecto.Query, warn: false

  alias MayorGameWeb.WikiView

  alias Pow.Store.CredentialsCache
  # alias MayorGameWeb.Pow.Routes

  def render(assigns) do
    # use WikiView view to render city/show.html.leex template with assigns
    WikiView.render("show.html", assigns)
  end

  def mount(_params, _session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    MayorGameWeb.Endpoint.subscribe("cityPubSub")

    {:ok,
     socket
     |> assign(:section, nil)
     |> update_page()}
  end

  def handle_event(
        "nav_to_section",
        %{"section" => section},
        assigns = socket
      ) do
    {:noreply,
     socket
     |> assign(:section, section)
     |> update_page()}
  end

  def update_page(socket) do
    in_dev = Application.get_env(:mayor_game, :env) == :dev

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
    |> assign(:in_dev, in_dev)
    |> assign(:buildables, buildables_list)
    |> assign(:resources, resources_list)
    |> assign(:resources_flat, Resource.resources_flat())
    |> assign(:building_requirements, [
      "workers",
      "energy",
      "area",
      "money",
      "steel",
      "sulfur",
      "uranium"
    ])
    |> assign(:resource_category_descriptions, Resource.resource_category_descriptions())
    |> assign(:buildable_category_descriptions, Buildable.buildable_category_descriptions())
    # run helper function to get the stuff from the DB for those things
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    {:noreply, socket}
  end
end
