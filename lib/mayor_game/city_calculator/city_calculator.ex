defmodule MayorGame.CityCalculator do
  use GenServer, restart: :permanent
  alias MayorGame.{City, CityHelpers}
  # alias MayorGame.City.Details

  def start_link(initial_val) do
    # starts link based on this file
    # which triggers init function in module

    GenServer.start_link(__MODULE__, initial_val)
  end

  def init(initial_val) do
    # initial_val is 0 here, set in application.ex then started with start_link

    # send message :tax to self process after 5000ms
    Process.send_after(self(), :tax, 5000)

    # returns ok tuple when u start
    {:ok, initial_val}
  end

  # when tick is sent
  def handle_info(:tax, val) do
    cities = City.list_cities_preload()
    world = MayorGame.Repo.get!(MayorGame.City.World, 1)
    City.update_world(world, %{day: world.day + 1})
    IO.puts("day: " <> to_string(world.day) <> "——————————————————————————————————————————————")

    # result is map %{cities_w_room: [], citizens_looking: []}
    leftovers =
      # go through all cities
      Enum.reduce(cities, %{cities_w_room: [], citizens_looking: []}, fn city, acc ->
        # result here is %{jobs: #, housing: #, tax: #, money: #, citizens_looking: []}
        city_stats = CityHelpers.calculate_city_stats(city, world.day)

        city_calc =
          CityHelpers.calculate_stats_based_on_citizens(city.citizens, city_stats, world.day)

        # should i loop through citizens here, instead of in calculate_city_stats?
        # that way I can use the same function later?

        updated_city_treasury =
          if city_calc.money.available_money + city_calc.tax < 0,
            do: 0,
            else: city_calc.money.available_money + city_calc.tax

        # check here for if tax_income - money is less than zero
        case City.update_details(city.detail, %{city_treasury: updated_city_treasury}) do
          {:ok, _updated_details} ->
            City.update_log(
              city,
              "tax income: " <>
                to_string(city_calc.tax) <> " operating cost: " <> to_string(city_calc.money.cost)
            )

          {:error, err} ->
            IO.inspect(err)
        end

        # if city has leftover jobs
        are_there_jobs = Enum.any?(city_calc.jobs, fn {_level, number} -> number > 0 end)

        %{
          cities_w_room:
            if(city_calc.housing > 0 && are_there_jobs,
              do: [Map.put(city_calc, :city, city) | acc.cities_w_room],
              else: acc.cities_w_room
            ),
          citizens_looking: city_calc.citizens_looking ++ acc.citizens_looking
        }
      end)

    # SECOND ROUND CHECK (move citizens to better city, etc) here
    # if there are cities with room at all:
    if List.first(leftovers.cities_w_room) != nil do
      # for each citizen
      Enum.reduce(leftovers.citizens_looking, leftovers.cities_w_room, fn citizen,
                                                                          acc_city_list ->
        # results are map %{best_city: %{city: city, jobs: #, housing: #, etc}, job_level: #}
        best_job = CityHelpers.find_best_job(acc_city_list, citizen)

        if not is_nil(best_job) do
          # move citizen to city
          CityHelpers.move_citizen(citizen, best_job.best_city.city, world.day)

          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1.city == best_job.best_city.city))

          # make updated list, decrement housing and jobs
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              update
              |> Map.update!(:housing, &(&1 - 1))
              |> update_in([:jobs, best_job.job_level], &(&1 - 1))
            end)

          updated_acc_city_list
        else
          # check here if city citizen wants to move from has housing or not
          CityHelpers.kill_citizen(citizen)
          acc_city_list
        end
      end)
    else
      Enum.map(leftovers.citizens_looking, fn citizen ->
        CityHelpers.kill_citizen(citizen)
      end)
    end

    # send val to liveView process that manages frontEnd; this basically sends to every client.
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "ping",
      val
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 5000)
    {:noreply, world.day + 1}
  end

end
