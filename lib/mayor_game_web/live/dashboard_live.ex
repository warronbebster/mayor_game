defmodule MayorGameWeb.DashboardLive do
  require Logger

  use Phoenix.LiveView, container: {:div, [class: "row"]}
  use Phoenix.HTML

  alias MayorGame.City
  alias MayorGame.City.Info
  alias MayorGameWeb.DashboardView
  # alias MayorGame.Repo
  alias Ecto.Changeset

  def render(assigns) do
    DashboardView.render("show.html", assigns)
  end

  def mount(_params, %{"current_user" => current_user}, socket) do
    {:ok,
     socket
     |> assign(current_user: current_user)
     |> assign_new_city_changeset()
     |> assign_cities(current_user)}
  end

  # Build a changeset for the newly created city,
  #
  # We'll use the changeset to drive a form to be displayed in the rendered template.
  defp assign_new_city_changeset(socket) do
    changeset =
      %Info{}
      |> Info.changeset(%{
        "user" => [%{user_id: socket.assigns[:current_user].id}]
      })

    assign(socket, :city_changeset, changeset)
  end

  # Create a city based on the payload that comes from the form (matched as `city_form`).
  # If its title is blank, build a title randomly
  # Finally, reload the current user's `cities` association, and re-assign it to the socket,
  # so the template will be re-rendered.
  def handle_event(
        "create_city",
        # grab "info" map from response and cast it into city_form
        %{"info" => city_form},
        # pattern match to pull these variables out of the socket
        %{
          assigns: %{
            city_changeset: changeset,
            current_user: current_user,
            cities: cities
          }
        } = socket
      ) do
    city_form = Map.put(city_form, "user_id", current_user.id)

    # ok this needs to give attributes of user, title, region?
    case City.create_city(city_form) do
      # if city built successfully
      {:ok, _} ->
        # return assign to update cities in socket assigns
        {:noreply,
         assign(
           socket,
           :cities,
           City.list_cities()
           #  Repo.preload(current_user, :info, force: true)
         )}

      {:error, err} ->
        Logger.error(inspect(err))
    end
  end

  # Assign all cities as the cities list. Maybe I should figure out a way to only show cities for that user.
  defp assign_cities(socket, _current_user) do
    cities = City.list_cities()

    assign(socket, :cities, cities)
  end

  defp build_title() do
    randomString = :crypto.strong_rand_bytes(4) |> Base.encode64() |> binary_part(0, 4)
    String.replace(randomString, "/", "a") <> "ville"
  end
end
