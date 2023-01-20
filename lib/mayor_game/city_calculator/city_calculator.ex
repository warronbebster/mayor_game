defmodule MayorGame.CityCalculator do
  use GenServer, restart: :permanent
  alias MayorGame.{City, CityHelpers}
  # alias MayorGame.City.Details

  def start_link(initial_val) do
    IO.puts('start_city_calculator_link')
    # starts link based on this file
    # which triggers init function in module

    # check here if world exists already
    case City.get_world(initial_val) do
      %City.World{} -> IO.puts("world exists already!")
      nil -> City.create_world(%{day: 0, pollution: 0})
    end

    # this calls init function
    GenServer.start_link(__MODULE__, initial_val)
  end

  def init(initial_world) do
    IO.puts('init')
    # initial_val is 1 here, set in application.ex then started with start_link

    game_world = City.get_world!(initial_world)
    IO.inspect(game_world)

    # send message :tax to self process after 5000ms
    # calls `handle_info` function
    Process.send_after(self(), :tax, 10000)

    # returns ok tuple when u start
    {:ok, game_world}
  end

  # when :tax is sent
  def handle_info(:tax, world) do
    cities = City.list_cities_preload()
    cities_count = Enum.count(cities)

    pollution_ceiling =
      cities_count * 10000_000 +
        10000_000 * Random.gammavariate(7.5, 1)

    db_world = City.get_world!(1)

    IO.puts(
      "day: " <>
        to_string(db_world.day) <>
        " | cities: " <>
        to_string(cities_count) <>
        " | pollution: " <>
        to_string(db_world.pollution) <> " | —————————————————————————————————————————————"
    )

    cities_list = if rem(db_world.day, 2) == 1, do: Enum.reverse(cities), else: cities

    # result is map %{cities_w_room: [], citizens_looking: [], citizens_to_reproduce: [], etc}
    # FIRST ROUND CHECK
    # go through all cities
    # could try flowing this
    leftovers =
      Enum.reduce(
        cities_list,
        %{
          all_cities: [],
          all_cities_new: [],
          citizens_looking: [],
          citizens_out_of_room: [],
          citizens_learning: %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => []},
          citizens_too_old: [],
          citizens_polluted: [],
          citizens_to_reproduce: [],
          new_world_pollution: 0
        },
        fn city, acc ->
          # result here is a %Town{} with stats calculated
          city_with_stats = MayorGame.CityHelpers.calculate_city_stats(city, db_world)

          city_with_stats2 =
            MayorGame.CityHelpersTwo.calculate_city_stats(
              city,
              db_world,
              cities_count,
              pollution_ceiling
            )

          if city.id == 2 do
            # IO.inspect(
            #   Map.drop(city_with_stats2, [
            #     :details,
            #     :citizens,
            #     :employed_citizens,
            #     :result_buildables,
            #     :buildables,
            #     :logs
            #   ])
            # )
            # IO.inspect(city_with_stats2.housing_left, label: 'housing_left')
            # IO.inspect(city_with_stats2.pollution, label: 'pollution')
            # IO.inspect(city_with_stats2.tax_rates, label: 'tax_rates')
            # IO.inspect(city_with_stats2.sprawl, label: 'sprawl')
            # IO.inspect(city_with_stats2.fun, label: 'fun')
            # IO.inspect(city_with_stats2.health, label: 'health')
          end

          city_calculated_values =
            CityHelpers.calculate_stats_based_on_citizens(
              city_with_stats,
              db_world,
              cities_count
            )

          # should i loop through citizens here, instead of in calculate_city_stats?
          # that way I can use the same function later?

          # updated_city_treasury =
          #   if city_with_stats2.money < 0,
          #     do: 0,
          #     else: city_with_stats2.money

          # # check here for if tax_income - money is less than zero
          # # TODO: move this outside the enum to a multi update
          # case City.update_details(city.details, %{
          #        city_treasury: updated_city_treasury,
          #        pollution: city_with_stats2.pollution
          #      }) do
          #   {:ok, updated_details} ->
          #     nil

          #   {:error, err} ->
          #     IO.inspect(err)
          # end

          %{
            all_cities_new: [city_with_stats2 | acc.all_cities_new],
            all_cities: [city_calculated_values | acc.all_cities],
            citizens_too_old: city_with_stats2.old_citizens ++ acc.citizens_too_old,
            citizens_learning:
              Map.merge(city_with_stats2.educated_citizens, acc.citizens_learning, fn _k,
                                                                                      v1,
                                                                                      v2 ->
                v1 ++ v2
              end),
            citizens_polluted: city_with_stats2.polluted_citizens ++ acc.citizens_polluted,
            citizens_to_reproduce:
              city_with_stats2.reproducing_citizens ++ acc.citizens_to_reproduce,
            citizens_out_of_room:
              city_calculated_values.citizens_out_of_room ++ acc.citizens_out_of_room,
            citizens_looking: city_calculated_values.citizens_looking ++ acc.citizens_looking,
            new_world_pollution: city_with_stats2.pollution + acc.new_world_pollution
          }
        end
      )

    # ok so here each city has

    # educated citizens (map of level to list of citizens)
    # gotta multi educate here

    # housed_employed_looking_citizens
    # housed_employed_citizens
    # check tax rates for these to decide if they're looking
    # housed_citizens (no job)
    # unhoused_citizens (no anything)

    # first filter by job level?
    # get rating for each citizen for each city (or each housing slot?)
    # run hungarian
    # hungarian actually doesn't need to affect housing count because the citizens are just trading
    # 1 slot for each citizen looking, and 1 for each housing slot in housing_left

    # this is where the cities are done
    # first kill the polluted citizens and old citizens
    # should I add housing back to the cities in that case? probably

    # IO.inspect(Enum.max(Enum.map(leftovers.all_cities_new, &nil_value_check(&1, :pollution))),
    #   label: "pollution max"
    # )

    # IO.inspect(Enum.max(Enum.map(leftovers.all_cities_new, &nil_value_check(&1, :sprawl))),
    #   label: "sprawl max"
    # )

    # IO.inspect(Enum.max(Enum.map(leftovers.all_cities_new, &nil_value_check(&1, :fun))),
    #   label: "fun max"
    # )

    # IO.inspect(Enum.max(Enum.map(leftovers.all_cities_new, &nil_value_check(&1, :health))),
    #   label: "health max"
    # )

    # MULTI UPDATE: update city money/treasury in DB
    leftovers.all_cities_new
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {city, idx}, multi ->
      updated_city_treasury =
        if city.money < 0,
          do: 0,
          else: city.money

      details_update_changeset =
        city.details
        |> MayorGame.City.Details.changeset(%{
          city_treasury: updated_city_treasury,
          pollution: city.pollution
        })

      Ecto.Multi.update(multi, {:update_towns, idx}, details_update_changeset)
    end)
    |> MayorGame.Repo.transaction()

    # MULTI CHANGESET EDUCATE
    leftovers.citizens_learning
    |> Enum.map(fn {level, list} ->
      list
      |> Enum.with_index()
      |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
        town = City.get_town!(citizen.town_id)

        log =
          MayorGame.CityHelpersTwo.describe_citizen(citizen) <>
            " has graduated to level " <> to_string(level)

        # if list is longer than 50, remove last item
        limited_log = update_logs(log, town.logs)

        citizen_changeset =
          citizen
          |> MayorGame.City.Citizens.changeset(%{education: level})

        town_changeset =
          town
          |> MayorGame.City.Town.changeset(%{logs: limited_log})

        Ecto.Multi.update(multi, {:update_citizen_edu, idx}, citizen_changeset)
        |> Ecto.Multi.update({:update_town_log, idx}, town_changeset)
      end)
      |> MayorGame.Repo.transaction()
    end)

    # CHECK —————
    # FIRST CITIZEN CHECK: AGE DEATHS
    # Enum.each(leftovers.citizens_too_old, fn citizen ->
    #   CityHelpers.kill_citizen(citizen, citizen.name <> " has died of old age")
    #   # add 1 to available_housing for citizen's city
    # end)
    # MULTI CHANGESET KILL OLD CITIZENS
    leftovers.citizens_too_old
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
      town = City.get_town!(citizen.town_id)

      log =
        MayorGame.CityHelpersTwo.describe_citizen(citizen) <> " has died because of old age. RIP"

      # if list is longer than 50, remove last item
      limited_log = update_logs(log, town.logs)

      town_changeset =
        town
        |> MayorGame.City.Town.changeset(%{logs: limited_log})

      Ecto.Multi.delete(multi, {:delete, idx}, citizen)
      |> Ecto.Multi.update({:update, idx}, town_changeset)
    end)
    |> MayorGame.Repo.transaction()

    # MULTI KILL POLLUTED CITIZENS
    leftovers.citizens_polluted
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
      town = City.get_town!(citizen.town_id)

      log =
        MayorGame.CityHelpersTwo.describe_citizen(citizen) <>
          " has died because of pollution. RIP"

      limited_log = update_logs(log, town.logs)

      town_changeset =
        town
        |> MayorGame.City.Town.changeset(%{logs: limited_log})

      Ecto.Multi.delete(multi, {:delete, idx}, citizen)
      |> Ecto.Multi.update({:update, idx}, town_changeset)
    end)
    |> MayorGame.Repo.transaction()

    # MULTI REPRODUCE
    leftovers.citizens_to_reproduce
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
      town = City.get_town!(citizen.town_id)

      log =
        MayorGame.CityHelpersTwo.describe_citizen(citizen) <>
          " had a child"

      limited_log = update_logs(log, town.logs)
      # if list is longer than 50, remove last item

      changeset =
        City.create_citizens_changeset(%{
          money: 0,
          town_id: citizen.town_id,
          age: 0,
          education: 0,
          has_car: false,
          has_job: false,
          last_moved: db_world.day
        })

      town_changeset =
        town
        |> MayorGame.City.Town.changeset(%{logs: limited_log})

      Ecto.Multi.insert(multi, {:add_citizen, idx}, changeset)
      |> Ecto.Multi.update({:update, idx}, town_changeset)
    end)
    |> MayorGame.Repo.transaction()

    # CHECK —————
    # FOURTH CITIZEN CHECK: LOOKING FOR workers

    # if there are cities with room at all (if a city has room, this list won't be empty):
    cities_after_job_search =
      Enum.reduce(leftovers.citizens_looking, leftovers.all_cities, fn citizen, acc_city_list ->
        cities_with_housing_and_workers =
          Enum.filter(acc_city_list, fn city -> city.available_housing > 0 end)
          |> Enum.filter(fn city ->
            Enum.any?(city.workers, fn {_level, number} -> number > 0 end)
          end)

        # results are map %{best_city: %{city: city, workers: #, housing: #, etc}, job_level: #}
        best_job = CityHelpers.find_best_job(cities_with_housing_and_workers, citizen)

        if !is_nil(best_job) do
          # move citizen to city

          # TODO: check last_moved date here
          # although this could result in looking citizens staying in a city even though there's no housing
          # may need to consolidate out of room and looking
          # this is where the stale structs keep getting hit
          CityHelpers.move_citizen(citizen, City.get_town!(best_job.best_city.id), db_world.day)

          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1.id == best_job.best_city.id))

          # make updated list, decrement housing and workers
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              update
              |> Map.update!(:available_housing, &(&1 - 1))
              |> update_in([:workers, best_job.job_level], &(&1 - 1))
            end)

          updated_acc_city_list
        else
          acc_city_list
        end
      end)

    # IO.inspect(cities_after_job_search)
    # ok, available housing looks right here

    # CHECK —————
    # LAST CITIZEN CHECK: OUT OF ROOM
    Enum.reduce(leftovers.citizens_out_of_room, cities_after_job_search, fn citizen_out_of_room,
                                                                            acc_city_list ->
      cities_with_housing = Enum.filter(acc_city_list, fn city -> city.available_housing > 0 end)

      best_job = CityHelpers.find_best_job(cities_with_housing, citizen_out_of_room)

      if !is_nil(best_job) do
        # move citizen to city

        # TODO: check last_moved date here
        # although this could result in looking citizens staying in a city even though there's no housing
        # may need to consolidate out of room and looking
        CityHelpers.move_citizen(
          citizen_out_of_room,
          City.get_town!(best_job.best_city.id),
          db_world.day
        )

        # find where the city is in the list
        indexx = Enum.find_index(acc_city_list, &(&1.id == best_job.best_city.id))

        # make updated list, decrement housing and workers
        updated_acc_city_list =
          List.update_at(acc_city_list, indexx, fn update ->
            update
            |> Map.update!(:available_housing, &(&1 - 1))
            |> update_in([:workers, best_job.job_level], &(&1 - 1))
          end)

        updated_acc_city_list

        # if no best job
      else
        # if there's any cities with housing left
        if cities_with_housing != [] do
          CityHelpers.move_citizen(
            citizen_out_of_room,
            City.get_town!(hd(cities_with_housing).id),
            db_world.day
          )

          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1.id == hd(cities_with_housing).id))

          # make updated list, decrement housing and workers
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              update
              |> Map.update!(:available_housing, &(&1 - 1))
            end)

          updated_acc_city_list
        else
          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1.id == citizen_out_of_room.town_id))

          # make updated list, decrement housing
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              Map.update!(update, :available_housing, &(&1 + 1))
            end)

          CityHelpers.kill_citizen(citizen_out_of_room, "no housing available")

          updated_acc_city_list
        end
      end
    end)

    updated_pollution =
      if db_world.pollution + leftovers.new_world_pollution < 0 do
        0
      else
        db_world.pollution + leftovers.new_world_pollution
      end

    # update World in DB, pull updated_world var out of response
    {:ok, updated_world} =
      City.update_world(db_world, %{
        day: db_world.day + 1,
        pollution: updated_pollution
      })

    # SEND RESULTS TO CLIENTS
    # send val to liveView process that manages front-end; this basically sends to every client.
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "ping",
      updated_world
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 5000)

    # returns this to whatever calls ?
    {:noreply, updated_world}
  end

  def update_logs(log, existing_logs) do
    updated_log = [log | existing_logs]

    if length(updated_log) > 50 do
      updated_log |> Enum.reverse() |> tl() |> Enum.reverse()
    else
      updated_log
    end
  end

  def nil_value_check(map, key) do
    if Map.has_key?(map, key), do: map[key], else: 0
  end
end
