# this file serves to the front-end and talks to the back-end

defmodule MayorGameWeb.CityLive do
  require Logger
  use Phoenix.LiveView, container: {:div, class: "liveview-container"}
  use Phoenix.HTML

  alias MayorGame.{City, Repo, Rules, CityCombat, CityHelpers}
  alias MayorGame.City.{Town, Buildable, Citizens, OngoingAttacks}

  import Ecto.Query, warn: false

  alias MayorGameWeb.CityView

  alias Pow.Store.CredentialsCache

  def render(assigns) do
    # use CityView view to render city/show.html.leex template with assigns
    CityView.render("show.html", assigns)
  end

  def mount(%{"title" => title}, session, socket) do
    # subscribe to the channel "cityPubSub". everyone subscribes to this channel

    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    world = Repo.get!(MayorGame.City.World, 1)
    in_dev = Application.get_env(:mayor_game, :env) == :dev

    resource_types = [
      {:sulfur, "text-orange-700"},
      {:uranium, "text-violet-700"},
      {:steel, "text-slate-700"},
      {:fish, "text-cyan-700"},
      {:oil, "text-stone-700"},
      {:stone, "text-slate-700"},
      {:bread, "text-amber-800"},
      {:wheat, "text-amber-600"},
      {:grapes, "text-indigo-700"},
      {:wood, "text-amber-700"},
      {:food, "text-yellow-700"},
      {:produce, "text-green-700"},
      {:meat, "text-red-700"},
      {:rice, "text-yellow-700"},
      {:cows, "text-stone-700"},
      {:lithium, "text-lime-700"},
      {:water, "text-sky-700"},
      {:salt, "text-zinc-700"},
      {:missiles, "text-red-700"},
      {:shields, "text-blue-700"}
    ]

    subtotal_types =
      [
        {:health, "text-rose-700"},
        {:area, "text-cyan-700"},
        {:housing, "text-amber-700"},
        {:energy, "text-yellow-700"},
        {:culture, "text-blue-700"},
        {:sprawl, "text-yellow-700"}
      ] ++ resource_types

    explanations = %{
      transit: "Build transit to add area to your city. Area is required to build most other buildings.",
      energy:
        "Energy buildings produce energy when they're operational. Energy is required to operate most other buildings. You need citizens to operate most of the energy buildings.",
      housing:
        "Housing is required to retain citizens — otherwise, they'll die. Housing requires energy and area; if you run out of energy, you might run out of housing rather quickly!",
      education:
        "Education buildings will, once a year, move citizens up an education level. This allows them to work at buildings with higher job levels, and make more money (and you, too, through taxes!",
      civic: "Civic buildings add other benefits citizens like — jobs, fun, etc.",
      resources:
        "Resource buildings are ways to generate in-game resources. Some regions have unique resource buildings.",
      farms: "Farms generate resources related to fooc & consumption.",
      food: "Food buildings allow you to distribute food to your citizens.",
      commerce: "Commerce buildings have lots of jobs to attract citizens to your city",
      entertainment: "Entertainment buildings have jobs, and add other intangibles to your city.",
      travel: "Travel buildings increase your city's desirability.",
      health: "Health buildings increase the health of your citizens, and make them less likely to die",
      combat: "Combat buildings let you attack other cities, or defend your city from attack.",
      storage: "Storage buildings let you store more of certain resources."
    }

    buildables_map = %{
      buildables_flat: Buildable.buildables_flat(),
      buildables: Buildable.buildables(),
      buildables_kw_list: Buildable.buildables_kw_list(),
      buildables_list: Buildable.buildables_list(),
      buildables_default_priorities: Buildable.buildables_default_priorities()
    }

    # production_categories = [:energy, :area, :housing]

    {
      :ok,
      socket
      # put the title and day in assigns
      |> assign(:title, title)
      |> assign(:world, world)
      |> assign(:in_dev, in_dev)
      # |> assign(:form, City.update_town(%Town{}))
      |> assign(:buildables_map, buildables_map)
      |> assign(:building_requirements, [
        "workers",
        "energy",
        "area",
        "money",
        "steel",
        "sulfur",
        "uranium",
        "rice",
        "meat",
        "water",
        "cows",
        "bread",
        "wheat",
        "produce",
        "salt"
      ])
      |> assign(:category_explanations, explanations)
      |> assign(:subtotal_types, subtotal_types)
      |> assign(:resource_types, resource_types)
      |> update_city_by_title()
      |> assign_auth(session)
      |> update_current_user()
      |> assign_changesets()
      # run helper function to get the stuff from the DB for those things
    }
  end

  # this handles different events
  def handle_event(
        "add_citizen",
        _value,
        # pull these variables out of the socket
        %{assigns: %{city: city, world: world}} = socket
      ) do
    if socket.assigns.current_user.id == 1 do
      IO.inspect(city.citizens_compressed)

      City.add_citizens(city, world.day)
    end

    {:noreply, socket |> update_city_by_title()}
  end

  # event
  def handle_event(
        "gib_money",
        _value,
        %{assigns: %{city: city}} = socket
      ) do
    if socket.assigns.current_user.id == 1 do
      case City.update_town(city, %{treasury: city.treasury + 10_000}) do
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
        %{"userid" => _user_id},
        %{assigns: %{city: city}} = socket
      ) do
    if socket.assigns.current_user.id == city.user_id || socket.assigns.current_user.id == 1 do
      # reset = Map.new(Buildable.buildables_list(), fn x -> {x, []} end)

      reset_buildables =
        Map.new(Enum.map(socket.assigns.buildables_map.buildables_list, fn building -> {building, 0} end))

      updated_attrs =
        reset_buildables
        |> Map.merge(%{
          treasury: 5000,
          pollution: 0,
          uranium: 0,
          steel: 0,
          missiles: 0,
          shields: 0,
          sulfur: 0,
          citizen_count: 0
        })

      case City.update_town(city, updated_attrs) do
        {:ok, _updated_town} ->
          IO.puts("city_reset")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  def handle_event(
        "reset_priorities",
        %{"userid" => _user_id},
        %{assigns: %{city: city}} = socket
      ) do
    if socket.assigns.current_user.id == city.user_id || socket.assigns.current_user.id == 1 do
      # reset = Map.new(Buildable.buildables_list(), fn x -> {x, []} end)

      reset_priorities = socket.assigns.buildables_map.buildables_default_priorities

      case City.update_town(city, %{priorities: reset_priorities}) do
        {:ok, _updated_town} ->
          IO.puts("priorities reset!")

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title()}
  end

  # PURCHASE BUILDING——————————————————————————————————————————————————————————————————————————

  def handle_event(
        "purchase_building",
        %{"building" => building_to_buy},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?
    building_to_buy_atom = String.to_existing_atom(building_to_buy)
    initial_purchase_price = get_in(socket.assigns.buildables_map.buildables_flat, [building_to_buy_atom, :price])

    fetched_value = Repo.one(from city in Town, where: city.id == ^city.id, select: ^[:id, building_to_buy_atom])
    buildable_count = fetched_value[building_to_buy_atom]

    building_reqs = get_in(socket.assigns.buildables_map.buildables_flat(), [building_to_buy_atom, :building_reqs])

    # buildable_count + socket.assigns.construction_count[building_to_buy_atom]

    purchase_price = Rules.building_price(initial_purchase_price, buildable_count)

    success =
      if socket.assigns.current_user.id == city.user_id do
        # check for upgrade requirements?
        case City.purchase_buildable(
               city,
               #  {socket.assigns.construction_count, socket.assigns.construction_cost},
               building_to_buy_atom,
               purchase_price,
               building_reqs
             ) do
          {_, nil} ->
            IO.puts('purchase success')
            true

          {:error, err} ->
            Logger.error(inspect(err))
            false

          _ ->
            false
        end
      end

    if success do
      new_construction_count =
        Map.update(socket.assigns.construction_count, building_to_buy_atom, 1, fn current -> current + 1 end)

      new_construction_cost = socket.assigns.construction_cost + purchase_price

      new_purchase_price = Rules.building_price(initial_purchase_price, buildable_count + 1)

      new_buildables =
        socket.assigns.buildables
        |> put_in(
          [
            socket.assigns.buildables_map.buildables_flat[building_to_buy_atom].category,
            building_to_buy_atom,
            :price
          ],
          new_purchase_price
        )

      # IO.inspect(socket.assigns.city_stats.resource_stats)

      updated_city_resource_stats =
        if is_nil(building_reqs) do
          socket.assigns.city_stats.resource_stats
        else
          Enum.reduce(building_reqs, socket.assigns.city_stats.resource_stats, fn {req_key, req_value}, acc ->
            Map.put(acc, req_key, Map.update!(acc[req_key], :stock, &(&1 - req_value)))
          end)
        end

      updated_city_stats =
        if is_nil(building_reqs) do
          socket.assigns.city_stats
        else
          Map.put(socket.assigns.city_stats, :resource_stats, updated_city_resource_stats)
        end

      {:noreply,
       socket
       |> assign(:construction_count, new_construction_count)
       |> assign(:construction_cost, new_construction_cost)
       |> assign(:buildables, new_buildables)
       |> assign(:city_stats, updated_city_stats)}
    else
      {:noreply, socket}
    end
  end

  # DEMOLISH ———————————————————————————————————————————————————————————————————————————
  # DEMOLISH ———————————————————————————————————————————————————————————————————————————
  # DEMOLISH ———————————————————————————————————————————————————————————————————————————

  def handle_event(
        "demolish_building",
        %{"building" => building_to_demolish},
        %{assigns: %{city: city}} = socket
      ) do
    # check if user is mayor here?

    buildable_to_demolish_atom = String.to_existing_atom(building_to_demolish)

    initial_purchase_price = get_in(Buildable.buildables_flat(), [buildable_to_demolish_atom, :price])

    fetched_value = Repo.one(from city in Town, where: city.id == ^city.id, select: ^[:id, buildable_to_demolish_atom])
    buildable_count = fetched_value[buildable_to_demolish_atom]

    purchase_price =
      if buildable_count > 0 do
        Rules.building_price(initial_purchase_price, buildable_count - 1)
      else
        initial_purchase_price
      end

    if socket.assigns.current_user.id == city.user_id && buildable_count > 0 do
      success =
        case City.demolish_buildable(
               city,
               {socket.assigns.construction_count, socket.assigns.construction_cost},
               buildable_to_demolish_atom
             ) do
          {_x, nil} ->
            IO.puts("demolition success")
            true

          {:error, err} ->
            Logger.error(inspect(err))
            false

          _ ->
            false
        end

      if success do
        new_construction_cost = socket.assigns.construction_cost - purchase_price

        new_construction_count =
          Map.update(socket.assigns.construction_count, buildable_to_demolish_atom, -1, fn current -> current - 1 end)

        new_purchase_price = Rules.building_price(initial_purchase_price, buildable_count - 1)

        new_buildables =
          socket.assigns.buildables
          |> put_in(
            [
              socket.assigns.buildables_map.buildables_flat[buildable_to_demolish_atom].category,
              buildable_to_demolish_atom,
              :price
            ],
            new_purchase_price
          )

        {:noreply,
         socket
         |> assign(:construction_count, new_construction_count)
         |> assign(:construction_cost, new_construction_cost)
         |> assign(:buildables, new_buildables)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "attack_building",
        %{"building" => building_to_attack},
        %{assigns: %{city: city, current_user: current_user}} = socket
      ) do
    # check if user is mayor here?
    building_to_attack_atom = String.to_existing_atom(building_to_attack)

    CityCombat.attack_building(city, current_user.town.id, building_to_attack_atom)

    # attacking_town_struct = Repo.get!(Town, current_user.town.id)
    # attacked_town_struct = struct(City.Town, city)

    # updated_attacked_logs = Map.update(city.logs_attacks, attacking_town_struct.title, 1, &(&1 + 1))

    # attacked_town_changeset =
    #   attacked_town_struct
    #   |> City.Town.changeset(%{
    #     logs_attacks: updated_attacked_logs
    #   })

    # if city.shields <= 0 && attacking_town_struct.missiles > 0 &&
    #      attacking_town_struct.air_bases > 0 && attacked_town_struct[building_to_attack_atom] > 0 do
    #   attack =
    #     Town
    #     |> where(id: ^city.id)
    #     |> Repo.update_all(inc: [{building_to_attack_atom, -1}])

    #   case attack do
    #     {_x, nil} ->
    #       from(t in Town, where: [id: ^current_user.town.id])
    #       |> Repo.update_all(inc: [missiles: -1])

    #       attack_building =
    #         Ecto.Multi.new()
    #         |> Ecto.Multi.update(
    #           {:update_attacked_town, attacked_town_struct.id},
    #           attacked_town_changeset
    #         )
    #         |> Repo.transaction(timeout: 10_000)

    #       case attack_building do
    #         {:ok, _updated_details} ->
    #           IO.puts("attack success")

    #         {:error, err} ->
    #           Logger.error(inspect(err))
    #       end

    #     {:error, err} ->
    #       Logger.error(inspect(err))
    #   end
    # end

    # this is all ya gotta do to update, baybee
    {:noreply, socket |> update_city_by_title() |> update_current_user()}
  end

  def handle_event(
        "update_tax_rates",
        %{"job_level" => job_level, "value" => updated_value},
        %{assigns: %{city: city}} = socket
      ) do
    updated_value_float = Float.parse(updated_value)

    if updated_value_float != :error do
      updated_value_constrained = elem(updated_value_float, 0) |> max(0.0) |> min(1.0) |> Float.round(2)

      # check if it's below 0 or above 1 or not a number

      updated_tax_rates = city.tax_rates |> Map.put(job_level, updated_value_constrained)

      if socket.assigns.current_user.id == city.user_id do
        # check if user is mayor here?
        from(t in Town,
          where: t.id == ^city.id,
          update: [
            set: [
              tax_rates: ^updated_tax_rates
            ]
          ]
        )
        |> Repo.update_all([])
      end

      # this is all ya gotta do to update, baybee
      new_city = Map.put(city, :tax_rates, updated_tax_rates)

      {:noreply, socket |> assign(city: new_city)}
    end
  end

  def handle_event(
        "update_priorities",
        %{"building_type" => building_type, "value" => updated_value},
        %{assigns: %{city: city}} = socket
      ) do
    updated_value_int = Integer.parse(updated_value)

    if updated_value_int != :error do
      updated_value_constrained = elem(updated_value_int, 0) |> max(0) |> min(100)

      # check if it's below 0 or above 1 or not a number

      updated_priorities = city.priorities |> Map.put(to_string(building_type), updated_value_constrained)

      if socket.assigns.current_user.id == city.user_id do
        # check if user is mayor here?
        from(t in Town,
          where: t.id == ^city.id,
          update: [
            set: [
              priorities: ^updated_priorities
            ]
          ]
        )
        |> Repo.update_all([])
      end

      # this is all ya gotta do to update, baybee
      new_city = Map.put(city, :priorities, updated_priorities)

      {:noreply, socket |> assign(city: new_city)}
    end
  end

  # this is what gets messages from CityCalculator
  # kinda weird that it recalculates so much
  # is it possible to just send the updated contents over the wire to each city?
  def handle_info(%{event: "ping", payload: world}, socket) do
    {:noreply, socket |> assign(:world, world) |> update_city_by_title()}
  end

  # this is what gets messages from CityCalculator
  def handle_info(%{event: "pong", payload: _world}, socket) do
    {:noreply, socket |> update_city_by_title()}
  end

  # this is just the generic handle_info if nothing else matches
  def handle_info(_assigns, socket) do
    # just update the whole city
    {:noreply, socket |> update_city_by_title()}
  end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_city_by_title(%{assigns: %{title: title, world: world}} = socket) do
    # cities_count = MayorGame.Repo.aggregate(City.Town, :count, :id)

    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    season = Rules.season_from_day(world.day)

    # This variable shall be unmodified. This way there is no need to recast it into a struct in other handle_info instructions.
    city =
      City.get_town_by_title!(title)
      |> CityHelpers.preload_city_check()

    town_stats =
      CityHelpers.calculate_city_stats(
        city,
        world,
        pollution_ceiling,
        season,
        socket.assigns.buildables_map,
        socket.assigns.in_dev,
        false
      )

    # ok, here the price is updated per each CombinedBuildable

    # have to have this separate from the actual city because the city might not have some buildables, but they're still purchasable
    # this status is for the whole category
    # this could be much simpler
    # this is ok, just bakes
    buildables_with_status =
      calculate_buildables_statuses(
        city,
        world,
        socket.assigns.buildables_map.buildables_kw_list
      )

    # this is still used
    operating_count =
      Enum.map(town_stats.buildable_stats, fn {name, buildable_stat} ->
        {name, buildable_stat.operational}
      end)
      |> Enum.into(%{})

    operating_tax =
      Enum.map(town_stats.buildable_stats, fn {category, _} ->
        {category,
         (
           buildable = socket.assigns.buildables_map.buildables_flat[category]

           if operating_count[category] != nil && Map.has_key?(buildable, :requires) &&
                buildable.requires != nil,
              do:
                if(Map.has_key?(buildable.requires, :workers),
                  do:
                    Rules.calculate_earnings(
                      operating_count[category] * buildable.requires.workers.count,
                      buildable.requires.workers.level,
                      city.tax_rates[to_string(buildable.requires.workers.level)]
                    ),
                  else: 0
                ),
              else: 0
         )}
      end)
      |> Enum.into(%{})

    tax_by_level =
      Enum.map(
        Enum.group_by(
          operating_tax,
          fn {category, _} ->
            buildable = socket.assigns.buildables_map.buildables_flat[category]

            if operating_count[category] != nil && Map.has_key?(buildable, :requires) &&
                 buildable.requires != nil,
               do:
                 if(Map.has_key?(buildable.requires, :workers),
                   do: buildable.requires.workers.level,
                   else: 0
                 ),
               else: 0
          end,
          fn {_, value} -> value end
        ),
        fn {level, array} -> {level, Enum.sum(array)} end
      )
      |> Enum.into(%{})

    citizen_edu_count = town_stats.citizen_count_by_level

    socket
    |> assign(:season, season)
    |> assign(:buildables, buildables_with_status)
    |> assign(:user_id, city.user.id)
    |> assign(:username, city.user.nickname)
    # don't modify city; use it as a baseline
    |> assign(:city, city)
    # use a separate object for calculated stats
    |> assign(:city_stats, town_stats)
    |> assign(:operating_count, operating_count)
    |> assign(:construction_count, %{})
    |> assign(:construction_cost, 0)
    |> assign(:operating_tax, operating_tax)
    |> assign(:tax_by_level, tax_by_level)

    # |> assign(:citizens_by_edu, citizen_edu_count)
  end

  # # function to mount city
  # defp mount_city_by_title(%{assigns: %{title: title}} = socket) do
  #   # this shouuuuld be fresh…
  #   city = City.get_town_by_title!(title)

  #   # grab whole user struct
  #   city_user = Auth.get_user!(city.user_id)

  #   socket
  #   |> assign(:user_id, city_user.id)
  #   |> assign(:username, city_user.nickname)
  # end

  # function to update city
  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(%{assigns: %{current_user: current_user}} = socket) do
    if !is_nil(current_user) do
      current_user_updated = current_user |> Repo.preload([:town])

      if is_nil(current_user_updated.town) do
        socket
        |> assign(:current_user, current_user_updated)
      else
        updated_town = City.get_town!(current_user_updated.town.id) |> Repo.preload([:attacks_sent])

        socket
        |> assign(:current_user, Map.put(current_user_updated, :town, updated_town))
      end
    else
      socket
    end
  end

  # maybe i should make one just for "updating" — e.g. only pull details and citizens from DB
  defp update_current_user(socket) do
    socket
  end

  # this takes the generic buildables map and builds the status (enabled, etc) for each buildable
  defp calculate_buildables_statuses(city, world, buildables) do
    Enum.map(buildables, fn {category, buildables} ->
      {category,
       buildables
       |> Enum.map(fn {_key, buildable_stats} ->
         {buildable_stats.title,
          Map.from_struct(
            calculate_buildable_status(
              buildable_stats,
              city,
              world,
              Map.get(city, buildable_stats.title)
            )
          )}
       end)}
    end)
  end

  # this takes a buildable, and builds purchasable status from database
  # TODO: Clean this shit upppp
  # why do I even need this lol. let you build but just
  defp calculate_buildable_status(buildable, city, world, buildable_count) do
    updated_price = Rules.building_price(buildable.price, buildable_count)

    buildable
    |> Map.put(
      :actual_produces,
      MayorGame.CityHelpers.get_production_map(
        buildable.produces,
        buildable.multipliers,
        city.citizen_count,
        city.region,
        Rules.season_from_day(world.day)
      )
    )
    |> Map.put(:price, updated_price)
  end

  # TRADING —————————————————————————————————————————————————————————————————————————————————————
  # ——————————————————————————————————————————————————————————————————

  # Create a city based on the payload that comes from the form (matched as `city_form`).
  # If its title is blank, build a title randomly
  # Finally, reload the current user's `cities` association, and re-assign it to the socket,
  # so the template will be re-rendered.
  def handle_event(
        "trade",
        # grab "town" map from response and cast it into city_form
        %{"town" => city_form},
        # pattern match to pull these variables out of the socket
        %{assigns: %{city: city, current_user: current_user}} = socket
      ) do
    giving_town_struct = Repo.get!(Town, current_user.town.id)
    receiving_town_struct = city

    resource =
      if city_form["resource"] != "",
        do: String.to_existing_atom(city_form["resource"]),
        else: nil

    resource_key = if resource == :money, do: :treasury, else: resource

    amount = if city_form["amount"] != "", do: String.to_integer(city_form["amount"]), else: 0
    neg_amount = 0 - amount

    changeset_check =
      if !is_nil(resource),
        do: %{resource_key => amount},
        else: %{}

    trade_set =
      if !is_nil(resource) do
        giving_town_struct
        |> Town.changeset(changeset_check)
        |> Ecto.Changeset.validate_number(resource_key,
          less_than: giving_town_struct[resource_key]
        )
      else
        giving_town_struct
        |> Town.changeset(%{})
      end

    # update cities

    if !is_nil(resource) && amount < giving_town_struct[resource_key] && amount > 0 do
      from(t in Town, where: [id: ^current_user.town.id])
      |> Repo.update_all(inc: [{resource_key, neg_amount}])

      from(t in Town, where: [id: ^city.id])
      |> Repo.update_all(inc: [{resource_key, amount}])

      updated_receiving_logs =
        if Map.has_key?(city.logs_received, giving_town_struct.title) do
          updated_town_map =
            Map.update(
              city.logs_received[giving_town_struct.title],
              to_string(resource_key),
              amount,
              &(&1 + amount)
            )

          Map.put(city.logs_received, giving_town_struct.title, updated_town_map)
        else
          Map.put(city.logs_received, giving_town_struct.title, %{
            to_string(resource_key) => amount
          })
        end

      # SENDING LOGS

      updated_sending_logs =
        if Map.has_key?(giving_town_struct.logs_sent, city.title) do
          updated_town_map =
            Map.update(
              giving_town_struct.logs_sent[city.title],
              to_string(resource_key),
              amount,
              &(&1 + amount)
            )

          Map.put(giving_town_struct.logs_sent, city.title, updated_town_map)
        else
          Map.put(giving_town_struct.logs_sent, city.title, %{to_string(resource_key) => amount})
        end

      receiving_town_changeset =
        receiving_town_struct
        |> City.Town.changeset(%{
          logs_received: updated_receiving_logs
        })

      sending_town_changeset =
        giving_town_struct
        |> City.Town.changeset(%{
          logs_sent: updated_sending_logs
        })

      # trade_changeset =
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        {:update_sending_town_logs, current_user.town.id},
        sending_town_changeset
      )
      |> Ecto.Multi.update({:update_recieving_town_logs, city.id}, receiving_town_changeset)
      |> Repo.transaction(timeout: 10_000)
    end

    # validation for form
    trade_set =
      if trade_set.errors == [] do
        Map.put(trade_set, :changes, %{amount: 0, resource: city_form["resource"]})
      else
        Map.put(trade_set, :changes, %{amount: amount, resource: city_form["resource"]})
        |> Map.update!(:errors, fn current -> [amount: elem(hd(current), 1)] end)
        |> Map.put(:action, :insert)
      end

    {:noreply, assign(socket, :trade_set, trade_set) |> update_city_by_title()}
  end

  def handle_event(
        "validate_trade",
        %{"town" => city_form},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    giving_town_struct = Repo.get!(Town, current_user.town.id)

    # new changeset from the form changes
    # new_changeset =
    #   Town.changeset(city, Map.put(city_form, "user_id", socket.assigns[:current_user].id))
    resource =
      if city_form["resource"] != "",
        do: String.to_existing_atom(city_form["resource"]),
        else: nil

    resource_key = if resource == :money, do: :treasury, else: resource
    amount = if city_form["amount"] != "", do: String.to_integer(city_form["amount"]), else: 0

    changeset_check =
      if !is_nil(resource),
        do: %{resource_key => amount},
        else: %{}

    trade_set =
      if !is_nil(resource) do
        giving_town_struct
        |> Town.changeset(changeset_check)
        |> Ecto.Changeset.validate_number(resource_key,
          less_than: giving_town_struct[resource_key]
        )
      else
        giving_town_struct
        |> Town.changeset(%{})
      end

    trade_set =
      if trade_set.errors == [] do
        Map.put(trade_set, :changes, %{amount: amount, resource: city_form["resource"]})
      else
        Map.put(trade_set, :changes, %{amount: amount, resource: city_form["resource"]})
        |> Map.update!(:errors, fn current -> [amount: elem(hd(current), 1)] end)
        |> Map.put(:action, :insert)
      end

    {:noreply, assign(socket, :trade_set, trade_set)}
  end

  def handle_event(
        "attack_shields",
        # grab "town" map from response and cast it into city_form
        %{"town" => city_form},
        # pattern match to pull these variables out of the socket
        %{assigns: %{city: city, current_user: current_user}} = socket
      ) do
    # if city.shields > 0 && attacking_town_struct.missiles > 0 do
    #   from(t in Town, where: [id: ^city.id])
    #   |> Repo.update_all(inc: [shields: -1])

    #   from(t in Town, where: [id: ^current_user.town.id])
    #   |> Repo.update_all(inc: [missiles: -1])

    # end

    # ————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————

    attacking_town_struct = Repo.get!(Town, current_user.town.id)
    shielded_town_struct = city

    amount = if city_form["amount"] != "", do: String.to_integer(city_form["amount"]), else: 1

    {status, city_after_attack, attack_changeset} = CityCombat.attack_shields(city, current_user.town.id, amount)
    # update cities

    # this is all ya gotta do to update, baybee
    # {:noreply, socket }
    if status == :ok do
      {:noreply,
       assign(socket, :attack_set, attack_changeset) |> assign(city: city_after_attack) |> update_current_user()}
    else
      # if not enough missiles/no air base
      {:noreply, socket}
    end
  end

  def handle_event(
        "commence_attack",
        # grab "town" map from response and cast it into city_form
        %{},
        # pattern match to pull these variables out of the socket
        %{assigns: %{city: city, current_user: current_user}} = socket
      ) do
    CityCombat.initiate_attack(city, current_user.town.id)

    # if not enough missiles/no air base
    {:noreply, socket |> update_city_by_title() |> update_current_user()}
  end

  def handle_event(
        "reduce_attack",
        # grab "town" map from response and cast it into city_form
        %{},
        # pattern match to pull these variables out of the socket
        %{assigns: %{city: city, current_user: current_user}} = socket
      ) do
    CityCombat.reduce_attack(city, current_user.town.id)

    # if not enough missiles/no air base
    {:noreply, socket |> update_city_by_title() |> update_current_user()}
  end

  def handle_event("toggle_retaliate", %{}, %{assigns: %{city: city, current_user: _current_user}} = socket) do
    City.update_town_by_id(city.id, %{retaliate: !city.retaliate})

    updated_city = city |> Map.update!(:retaliate, &(!&1))

    # if not enough missiles/no air base
    {:noreply, socket |> assign(:city, updated_city)}
  end

  # this is for the changeset for how many missiles to send
  def handle_event(
        "validate_attack",
        %{"town" => city_form},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    attacking_town_struct = Repo.get!(Town, current_user.town.id)

    # new changeset from the form changes
    # new_changeset =
    #   Town.changeset(city, Map.put(city_form, "user_id", socket.assigns[:current_user].id))

    amount = if city_form["amount"] != "", do: String.to_integer(city_form["amount"]), else: 0

    attack_set =
      attacking_town_struct
      |> Town.changeset(%{missiles: amount})
      |> Ecto.Changeset.validate_number(:missiles,
        less_than: attacking_town_struct.missiles
      )

    attack_set =
      if attack_set.errors == [] do
        Map.put(attack_set, :changes, %{amount: amount})
      else
        Map.put(attack_set, :changes, %{amount: amount})
        |> Map.update!(:errors, fn current -> [amount: elem(hd(current), 1)] end)
        |> Map.put(:action, :insert)
      end

    {:noreply, assign(socket, :attack_set, attack_set)}
  end

  # Build a changeset for the newly created city,
  # We'll use the changeset to drive a form to be displayed in the rendered template.
  defp assign_changesets(socket) do
    changeset =
      %Town{}
      |> Town.changeset(%{})

    attack_changeset =
      %Town{}
      |> Town.changeset(%{})
      |> Map.put(:changes, %{amount: 1})

    assign(socket, :trade_set, changeset)
    |> assign(:attack_set, attack_changeset)
  end

  # POW
  # AUTH
  # POW AUTH STUFF DOWN HERE BAYBEE ——————————————————————————————————————————————————————————————————

  defp assign_auth(socket, session) do
    date = Date.utc_today()
    # add an assign :current_user to the socket
    socket =
      assign_new(socket, :current_user, fn ->
        get_user(socket, session) |> Repo.preload([:town])
      end)

    if socket.assigns.current_user do
      # if there's a user logged in
      is_user_mayor =
        if !socket.assigns.in_dev,
          do: to_string(socket.assigns.user_id) == to_string(socket.assigns.current_user.id),
          else: to_string(socket.assigns.user_id) == to_string(socket.assigns.current_user.id)

      is_user_admin =
        if !socket.assigns.in_dev,
          do: socket.assigns.current_user.id == 1,
          else: true

      # auth check
      if is_user_mayor do
        City.update_town(socket.assigns.city, %{last_login: date})
      end

      socket |> assign(:is_user_mayor, is_user_mayor) |> assign(:is_user_admin, is_user_admin)
    else
      # if there's no user logged in
      socket |> assign(:is_user_mayor, false) |> assign(:is_user_admin, false)
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
