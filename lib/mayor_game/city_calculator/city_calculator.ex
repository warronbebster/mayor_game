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

    db_world = City.get_world!(1)

    IO.puts(
      "day: " <>
        to_string(db_world.day) <>
        " | cities: " <>
        to_string(cities_count) <>
        " | pollution: " <>
        to_string(db_world.pollution) <> " | —————————————————————————————————————————————"
    )

    # result is map %{cities_w_room: [], citizens_looking: [], citizens_to_reproduce: [], etc}
    # FIRST ROUND CHECK
    # go through all cities
    leftovers =
      Enum.reduce(
        cities,
        %{
          all_cities: [],
          citizens_looking: [],
          citizens_out_of_room: [],
          citizens_too_old: [],
          citizens_polluted: [],
          citizens_to_reproduce: [],
          new_world_pollution: 0
        },
        fn city, acc ->
          # result here is a %Town{} with stats calculated
          city_with_stats = CityHelpers.calculate_city_stats(city, db_world)

          city_calculated_values =
            CityHelpers.calculate_stats_based_on_citizens(
              city_with_stats,
              db_world,
              cities_count
            )

          # should i loop through citizens here, instead of in calculate_city_stats?
          # that way I can use the same function later?

          updated_city_treasury =
            if city_calculated_values.available_money + city_calculated_values.tax < 0,
              do: 0,
              else: city_calculated_values.available_money + city_calculated_values.tax

          # check here for if tax_income - money is less than zero
          case City.update_details(city.details, %{
                 city_treasury: updated_city_treasury,
                 pollution: city_calculated_values.pollution
               }) do
            {:ok, updated_details} ->
              nil

            {:error, err} ->
              IO.inspect(err)
          end

          %{
            all_cities: [city_calculated_values | acc.all_cities],
            citizens_too_old: city_calculated_values.citizens_too_old ++ acc.citizens_too_old,
            citizens_polluted: city_calculated_values.citizens_polluted ++ acc.citizens_polluted,
            citizens_to_reproduce:
              city_calculated_values.citizens_to_reproduce ++ acc.citizens_to_reproduce,
            citizens_out_of_room:
              city_calculated_values.citizens_out_of_room ++ acc.citizens_out_of_room,
            citizens_looking: city_calculated_values.citizens_looking ++ acc.citizens_looking,
            new_world_pollution: city_calculated_values.pollution + acc.new_world_pollution
          }
        end
      )

    # CHECK —————
    # FIRST CITIZEN CHECK: AGE DEATHS
    # Enum.each(leftovers.citizens_too_old, fn citizen ->
    #   CityHelpers.kill_citizen(citizen, citizen.name <> " has died of old age")
    #   # add 1 to available_housing for citizen's city
    # end)

    cities_after_aging_deaths =
      Enum.reduce(leftovers.citizens_too_old, leftovers.all_cities, fn citizen_too_old,
                                                                       acc_city_list ->
        # find where the city is in the list
        indexx = Enum.find_index(acc_city_list, &(&1.id == citizen_too_old.town_id))

        # make updated list, increment housing and workers
        updated_acc_city_list =
          List.update_at(acc_city_list, indexx, fn update ->
            update
            |> Map.update!(:available_housing, &(&1 + 1))

            # |> update_in([:workers, best_job.job_level], &(&1 - 1))
            # could update job count if we really knew which job level the citizen held
          end)

        CityHelpers.kill_citizen(citizen_too_old, "old age")

        updated_acc_city_list
      end)

    # CHECK —————
    # SECOND CITIZEN CHECK: POLLUTION DEATHS
    cities_after_pollution_deaths =
      Enum.reduce(leftovers.citizens_polluted, cities_after_aging_deaths, fn citizen_polluted,
                                                                             acc_city_list ->
        # find where the city is in the list
        indexx = Enum.find_index(acc_city_list, &(&1.id == citizen_polluted.town_id))

        # make updated list, increment housing and workers
        updated_acc_city_list =
          List.update_at(acc_city_list, indexx, fn update ->
            update
            |> Map.update!(:available_housing, &(&1 + 1))

            # |> update_in([:workers, best_job.job_level], &(&1 - 1))
            # could update job count if we really knew which job level the citizen held
          end)

        CityHelpers.kill_citizen(citizen_polluted, "high pollution levels")

        updated_acc_city_list
      end)

    # CHECK —————
    # THIRD CITIZEN CHECK: REPRODUCTION
    cities_after_reproduction =
      Enum.reduce(
        leftovers.citizens_to_reproduce,
        cities_after_pollution_deaths,
        fn citizen_to_reproduce, acc_city_list ->
          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1.id == citizen_to_reproduce.town_id))

          # make updated list, decrement housing
          # this is how a city can end up with negative housing
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              Map.update!(update, :available_housing, &(&1 - 1))
            end)

          {:ok, child_citizen} =
            City.create_citizens(%{
              money: 0,
              town_id: citizen_to_reproduce.town_id,
              age: 0,
              education: 0,
              has_car: false,
              last_moved: db_world.day
            })

          City.update_log(
            City.get_town!(citizen_to_reproduce.town_id),
            CityHelpers.describe_citizen(citizen_to_reproduce) <>
              " had a child: " <> CityHelpers.describe_citizen(child_citizen)
          )

          updated_acc_city_list
        end
      )

    # CHECK —————
    # FOURTH CITIZEN CHECK: LOOKING FOR workers

    # if there are cities with room at all (if a city has room, this list won't be empty):
    cities_after_job_search =
      Enum.reduce(leftovers.citizens_looking, cities_after_reproduction, fn citizen,
                                                                            acc_city_list ->
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
    Process.send_after(self(), :tax, 10000)

    # returns this to whatever calls ?
    {:noreply, updated_world}
  end
end
