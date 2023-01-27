# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.{Auth, City, Repo}
  # import MayorGame.CityHelpers
  alias MayorGame.City.Buildable

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache
  # alias MayorGameWeb.Pow.Routes

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  def mount(%{"title" => title}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel
    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    world = Repo.get!(MayorGame.City.World, 1)

    explanations = %{
      transit:
        "Build transit to add area to your city. Area is required to build most other buildings.",
      energy:
        "Energy buildings produce energy when they're operational. Energy is required to operate most other buildings. You need citizens to operate most of the energy buildings.",
      housing:
        "Housing is required to retain citizens — otherwise, they'll die. Housing requires energy and area; if you run out of energy, you might run out of housing rather quickly!",
      education:
        "Education buildings will, once a year, move citizens up an education level. This allows them to work at buildings with higher job levels, and make more money (and you, too, through taxes!",
      civic: "Civic buildings add other benefits citizens like — jobs, fun, etc.",
      work: "Work buildings have lots of jobs to attract citizens to your city",
      entertainment: "Entertainment buildings have jobs, and add other intangibles to your city.",
      health:
        "Health buildings increase the health of your citizens, and make them less likely to die"
    }

    production_categories = [:energy, :area, :housing]

    {
      :ok,
      socket
      # put the title and day in assigns
      |> assign(:title, title)
      |> assign(:world, world)
      |> assign(:building_requirements, ["workers", "energy", "area", "money"])
      |> assign(:category_explanations, explanations)
      |> update_city_by_title()
      |> assign_auth(session)
      # run helper function to get the stuff from the DB for those things
    }
  end

  # this handles different events
  def handle_event(
        "add_citizen",
        _value,
        # pull these variables out of the socket
        %{assigns: %{city2: city}} = socket
      ) do
    if socket.assigns.current_user.id == 1 do
      case City.create_citizens(%{
             town_id: city.id,
             money: 5,
             education: 0,
             age: 0,
             has_job: false,
             has_car: false,
             last_moved: socket.assigns.world.day
           }) do
        # pattern match to assign new_citizen to what's returned from City.create_citizens
        {:ok, _updated_citizens} ->
          IO.inspect("updated 1 citizen")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    {:noreply, socket |> update_city_by_title()}
  end

  # event
  def handle_event(
        "gib_money",
        _value,
        %{assigns: %{city2: city}} = socket
      ) do
    city_struct = struct(City.Town, city)

    if socket.assigns.current_user.id == 1 do
      case City.update_town(city_struct, %{treasury: city.treasury + 1000}) do
        {:ok, _updated_town} ->
          IO.puts("money gabe")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "reset_city",
        %{"userid" => user_id},
        %{assigns: %{city2: city}} = socket
      ) do
    if socket.assigns.current_user.id == city.user_id do
      reset = Map.new(Buildable.buildables_list(), fn x -> {x, []} end)

      for building_type <- Buildable.buildables_list() do
        if city.details[building_type] != [] do
          for buildable <- city.details[building_type] do
            case City.demolish_buildable(city.details, building_type, buildable.buildable.id) do
              {:ok, _updated_details} ->
                IO.puts("demolition success")

              {:error, err} ->
                Logger.error(inspect(err))
            end
          end
        end
      end

      # case City.demolish_buildable(city.details, building_to_demolish, buildable_id) do
      #   {:ok, _updated_details} ->
      #     IO.puts("demolition success")

      #   {:error, err} ->
      #     Logger.error(inspect(err))
      # end

      case City.update_details(city.details, %{city_treasury: 5000}) do
        {:ok, updated_town} ->
          IO.puts("city_reset")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "purchase_building",
        %{"building" => building_to_buy},
        %{assigns: %{city2: city}} = socket
      ) do
    # check if user is mayor here?

    building_to_buy_atom = String.to_existing_atom(building_to_buy)

    # get exponential price — don't want to set price on front-end for cheating reasons
    initial_purchase_price = get_in(Buildable.buildables_flat(), [building_to_buy_atom, :price])
    buildable_count = length(city.details[building_to_buy_atom])

    purchase_price = MayorGame.CityHelpers.building_price(initial_purchase_price, buildable_count)

    city_struct = struct(City.Town, city)

    # check for upgrade requirements?

    case City.purchase_buildable(city_struct, building_to_buy_atom, purchase_price) do
      {:ok, _updated_details} ->
        nil

      {:error, err} ->
        Logger.error(inspect(err))

      nil ->
        nil
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  # def handle_event(
  #       "demolish_building",
  #       %{"building" => building_to_demolish, "buildable_id" => buildable_id},
  #       %{assigns: %{city: city}} = socket
  #     ) do
  #   # check if user is mayor here?
  #   buildable_to_demolish_atom = String.to_existing_atom(building_to_demolish)

  #   case City.demolish_buildable(city.details, buildable_to_demolish_atom, buildable_id) do
  #     {:ok, _updated_details} ->
  #       IO.puts("demolition success")

  #     {:error, err} ->
  #       Logger.error(inspect(err))
  #   end

  #   # this is all ya gotta do to update, baybee
  #   {:noreply, socket |> update_city_by_title()}
  # end

  def handle_event(
        "demolish_building_2",
        %{"building" => building_to_demolish},
        %{assigns: %{city2: city}} = socket
      ) do
    # check if user is mayor here?
    buildable_to_demolish_atom = String.to_existing_atom(building_to_demolish)

    # sometimes this is empty?
    buildable_to_id = hd(city.details[String.to_existing_atom(building_to_demolish)])
    buildable_id = buildable_to_id.buildable.id

    case City.demolish_buildable(city.details, buildable_to_demolish_atom, buildable_id) do
      {:ok, _updated_details} ->
        IO.puts("demolition success")

      {:error, err} ->
        Logger.error(inspect(err))
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "update_tax_rates",
        %{"job_level" => job_level, "value" => updated_value},
        %{assigns: %{city2: city}} = socket
      ) do
    # check if user is mayor here?
    updated_value_float = Float.parse(updated_value)

    if updated_value_float != :error do
      updated_value_constrained =
        elem(updated_value_float, 0) |> max(0.0) |> min(1.0) |> Float.round(2)

      IO.puts(to_string(updated_value_constrained))

      # check if it's below 0 or above 1 or not a number

      updated_tax_rates =
        city.tax_rates |> Map.put(job_level, updated_value_constrained) |> Map.drop(["6"])

      case City.update_town_by_id(city.id, %{tax_rates: updated_tax_rates}) do
        {:ok, _updated_details} ->
          IO.puts("tax rates updated")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  # this is what gets messages from CityCalculator
  def handle_info(%{event: "ping", payload: world}, socket) do
    {:noreply, socket |> assign(:world, world) |> update_city_by_title()}
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # just update the whole city
    {:noreply, socket |> update_city_by_title()}
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_city_by_title(%{assigns: %{title: title, world: world}} = socket) do
    cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)

    pollution_ceiling =
      cities_count * 10000_000 +
        10000_000 * Random.gammavariate(7.5, 1)

    season =
      cond do
        rem(world.day, 365) < 91 -> :winter
        rem(world.day, 365) < 182 -> :spring
        rem(world.day, 365) < 273 -> :summer
        true -> :fall
      end

    # this shouuuuld be fresh…
    city =
      City.get_town_by_title!(title)
      |> MayorGame.CityHelpers.preload_city_check()

    # grab whole user struct
    user = Auth.get_user!(city.user_id)

    # city_with_stats = MayorGame.CityHelpers.calculate_city_stats(city, world)

    city_with_stats2 =
      MayorGame.CityHelpers.calculate_city_stats(
        city,
        world,
        cities_count,
        pollution_ceiling
      )

    # ok, here the price is updated per each CombinedBuildable

    # have to have this separate from the actual city because the city might not have some buildables, but they're still purchasable
    # this status is for the whole category
    buildables_with_status = calculate_buildables_statuses(city_with_stats2)
    # IO.inspect(city_with_stats.details.airports)

    # mapped_details =
    #   Map.from_struct(city_with_stats2.details) |> Map.take(Buildable.buildables_list())

    empty_buildable_map = Map.new(Buildable.buildables_list(), fn x -> {x, []} end)

    mapped_details_2 =
      Enum.reduce(city_with_stats2.result_buildables, empty_buildable_map, fn buildable, acc ->
        Map.update!(acc, buildable.metadata.title, fn current_list ->
          [buildable | current_list]
        end)
      end)

    # need to get a map with the key

    operating_count =
      Enum.map(mapped_details_2, fn {category, list} ->
        {category, Enum.frequencies_by(list, fn x -> x.buildable.reason end)}
      end)
      |> Enum.into(%{})

    citizen_edu_count =
      Enum.frequencies_by(city_with_stats2.all_citizens, fn x -> x.education end)

    city2_without_citizens =
      Map.drop(city_with_stats2, [
        :citizens,
        :citizens_looking,
        :citizens_to_reproduce,
        :citizens_polluted,
        :resources,
        :citizens_looking,
        :education
      ])

    socket
    |> assign(:season, season)
    |> assign(:buildables, buildables_with_status)
    |> assign(:user_id, user.id)
    |> assign(:username, user.nickname)
    |> assign(:city2, city2_without_citizens)
    |> assign(:operating_count, operating_count)
    |> assign(:citizens_by_edu, citizen_edu_count)
    |> assign(:total_citizens, length(city_with_stats2.all_citizens))
  end

  # this takes the generic buildables map and builds the status (enabled, etc) for each buildable
  defp calculate_buildables_statuses(city) do
    Enum.map(Buildable.buildables_kw_list(), fn {category, buildables} ->
      {category,
       buildables
       |> Enum.map(fn {buildable_key, buildable_stats} ->
         {buildable_key,
          Map.from_struct(
            calculate_buildable_status(
              buildable_stats,
              city,
              length(Map.get(city.details, buildable_key))
            )
          )}
       end)}
    end)
  end

  # this takes a buildable metadata, and builds purchasable status from database
  # TODO: Clean this shit upppp
  defp calculate_buildable_status(buildable, city_with_stats, buildable_count) do
    updated_price = buildable.price * round(:math.pow(buildable_count, 2) + 1)

    if city_with_stats.money > updated_price do
      cond do
        # enough energy AND enough area

        (buildable.energy_required != nil || buildable.energy_required > 0) and
          city_with_stats.energy >= buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.area >= buildable.area_required) ->
          %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        # not enough energy, enough area
        buildable.energy_required != nil && buildable.energy_required > 0 and
          city_with_stats.energy < buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.area >= buildable.area_required) ->
          %{
            buildable
            | purchasable: false,
              purchasable_reason: "not enough energy to build",
              price: updated_price
          }

        # enough energy, not enough area
        buildable.energy_required != nil && buildable.energy_required > 0 and
          city_with_stats.energy >= buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.area < buildable.area_required) ->
          %{
            buildable
            | purchasable: false,
              purchasable_reason: "not enough area to build",
              price: updated_price
          }

        # not enough energy AND not enough area
        buildable.energy_required != nil && buildable.energy_required > 0 and
          city_with_stats.energy < buildable.energy_required &&
            (buildable.area_required != nil and
               city_with_stats.area < buildable.area_required) ->
          %{
            buildable
            | purchasable: false,
              purchasable_reason: "not enough area or energy to build",
              price: updated_price
          }

        # no energy needed, enough area
        buildable.energy_required != nil && buildable.energy_required > 0 &&
            (buildable.area_required != nil and
               city_with_stats.area >= buildable.area_required) ->
          %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        # no energy needed, not enough area
        buildable.energy_required != nil && buildable.energy_required > 0 &&
            (buildable.area_required != nil and
               city_with_stats.area < buildable.area_required) ->
          %{
            buildable
            | purchasable: false,
              purchasable_reason: "not enough area to build",
              price: updated_price
          }

        # no area needed, enough energy
        buildable.area_required == nil &&
            (buildable.energy_required != nil && buildable.energy_required > 0 and
               city_with_stats.energy >= buildable.energy_required) ->
          %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        # no area needed, not enough energy
        buildable.area_required == nil &&
            (buildable.energy_required != nil && buildable.energy_required > 0 and
               city_with_stats.energy < buildable.energy_required) ->
          %{
            buildable
            | purchasable: false,
              purchasable_reason: "not enough energy to build",
              price: updated_price
          }

        # no area needed, no energy needed
        (buildable.energy_required == nil || buildable.energy_required == 0) and
            buildable.area_required == nil ->
          %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}

        # catch-all
        true ->
          %{buildable | purchasable: true, purchasable_reason: "valid", price: updated_price}
      end
    else
      %{
        buildable
        | purchasable: false,
          purchasable_reason: "not enough money",
          price: updated_price
      }
    end
  end

  # POW
  # AUTH
  # POW AUTH STUFF DOWN HERE BAYBEE

  defp assign_auth(socket, session) do
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
           CredentialsCache.get([backend: Pow.Postgres.Store], token) do
      user
    else
      _any -> nil
    end
  end

  defp get_user(_, _, _), do: nil
end
