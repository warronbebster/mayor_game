defmodule MayorGame.Taxer do
  use GenServer, restart: :permanent
  alias MayorGame.City
  alias MayorGame.City.Details

  def start_link(initial_val) do
    # starts link based on this file
    # which triggers init function in module

    GenServer.start_link(__MODULE__, initial_val)
  end

  def init(initial_val) do
    # initial_val is 0 here, set in application.ex

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
      Enum.reduce(cities, %{cities_w_room: [], citizens_looking: []}, fn city, acc ->
        # result here is %{jobs: #, housing: #, tax: #, daily_cost: #, citizens_looking: []}
        city_calc = calculate_city_stats(city)

        updated_city_treasury =
          if city.detail.city_treasury + city_calc.tax - city_calc.daily_cost < 0 do
            # maybe some other consequences here
            0
          else
            city.detail.city_treasury + city_calc.tax - city_calc.daily_cost
          end

        # check here for if tax_income - daily_cost is less than zero
        case City.update_details(city.detail, %{
               city_treasury: updated_city_treasury
             }) do
          {:ok, _updated_details} ->
            City.update_log(
              city,
              "today's tax income:" <>
                to_string(city_calc.tax) <>
                " operating cost: " <>
                to_string(city_calc.daily_cost)
            )

          {:error, err} ->
            IO.inspect(err)
        end

        # if city isn't at capacity?
        are_there_jobs =
          Enum.any?(city_calc.jobs, fn {_level, amount_of_jobs} -> amount_of_jobs > 0 end)

        IO.puts("are there still jobs in " <> city.title <> ": " <> to_string(are_there_jobs))

        if city_calc.housing > 0 && are_there_jobs do
          %{
            cities_w_room: [Map.put(city_calc, :city, city) | acc.cities_w_room],
            citizens_looking: city_calc.citizens_looking ++ acc.citizens_looking
          }
        else
          %{
            cities_w_room: acc.cities_w_room,
            citizens_looking: city_calc.citizens_looking ++ acc.citizens_looking
          }
        end
      end)

    # SECOND ROUND CHECK (move citizens to better city, etc) here
    # if there are cities with room at all:
    if List.first(leftovers.cities_w_room) != nil do
      # for each citizen
      Enum.reduce(leftovers.citizens_looking, leftovers.cities_w_room, fn citizen,
                                                                          acc_city_list ->
        # results are map %{best_city: %{city: city, jobs: #, housing: #, etc}, job_level: #}
        best_job = find_best_job(acc_city_list, citizen)

        if not is_nil(best_job) do
          IO.puts(
            "housing left in " <>
              best_job.best_city.city.title <> ": " <> to_string(best_job.best_city.housing)
          )

          # move citizen to city
          move_citizen(citizen, best_job.best_city.city)

          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1 == best_job.best_city))

          # make updated list, decrement housing and jobs
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              update
              |> Map.update!(:housing, &(&1 - 1))
              |> update_in([:jobs, best_job.job_level], &(&1 - 1))
            end)

          # IO.inspect(
          #   Enum.map(updated_acc_city_list, fn city_calc ->
          #     Map.take(city_calc, [:housing, :city])
          #     |> Map.update!(:city, fn city ->
          #       Map.take(city, [:title])
          #     end)
          #   end)
          # )

          updated_acc_city_list
        else
          kill_citizen(citizen)

          acc_city_list
        end
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

  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW

  def move_citizen(%MayorGame.City.Citizens{} = citizen, %MayorGame.City.Info{} = city_to_move_to) do
    City.update_log(
      City.get_info!(citizen.info_id),
      citizen.name <> " moved to " <> city_to_move_to.title
    )

    City.update_citizens(citizen, %{info_id: city_to_move_to.id})
    City.update_log(city_to_move_to, citizen.name <> " just moved here")
  end

  def kill_citizen(%MayorGame.City.Citizens{} = citizen) do
    City.update_log(City.get_info!(citizen.info_id), citizen.name <> " has died. RIP")
    City.delete_citizens(citizen)
  end

  @doc """
  tries to find a city with matching job level. expects an array of city_calcs and a level to check.
  returns a city_calc map if successful, otherwise nil

  ## Examples
      iex> find_city_with_job(city_list, 2)
       %{city: city, jobs: #, housing: #, etc}
  """
  def find_city_with_job(cities, level) do
    city_result =
      Enum.reduce_while(cities, level, fn city_to_check, level_acc ->
        if is_number(city_to_check.jobs[level_acc]) &&
             city_to_check.jobs[level_acc] > 0 &&
             city_to_check.housing > 0,
           do: {:halt, city_to_check},
           else: {:cont, level_acc}
      end)

    # if there is no city with job
    if is_integer(city_result), do: nil, else: city_result
  end

  @doc """
  tries to find city with best match for citizen job based on education level
  takes list of city_calc maps and a %Citizens{} struct
  returns either city_calc map or nil if no results

  ## Examples
      iex> find_best_job(city_list, %Citizens{})
      %{best_city: %{city: city, jobs: #, housing: #, tax: #, cost: #, etc}, job_level: level_to_check}
  """
  def find_best_job(cities_to_check, %MayorGame.City.Citizens{} = citizen) do
    result =
      if citizen.education > 0 do
        # [3,2,1,0]
        levels = Enum.reverse(0..citizen.education)

        Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
          check_result = find_city_with_job(cities_to_check, level_to_check)

          if is_nil(check_result),
            do: {:cont, job_acc - 1},
            else: {:halt, %{best_city: check_result, job_level: level_to_check}}
        end)
      else
        check_result = find_city_with_job(cities_to_check, 0)
        if is_nil(check_result), do: -1, else: %{best_city: check_result, job_level: 0}
      end

    if is_integer(result), do: nil, else: result
  end

  def calculate_city_stats(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)
    daily_cost = calculate_daily_cost(city_preloaded)
    available_housing = calculate_housing(city_preloaded)
    # returns a map of %{0 => #, 0 => #, etc}
    available_jobs = calculate_jobs(city_preloaded)

    if List.first(city_preloaded.citizens) != nil do
      results =
        Enum.reduce(
          city_preloaded.citizens,
          %{
            jobs: available_jobs,
            tax: 0,
            housing: available_housing,
            daily_cost: daily_cost,
            citizens_looking: []
          },
          fn citizen, acc ->
            City.update_citizens(citizen, %{age: citizen.age + 1})

            # if there are NO jobs for citizen, returns -1.
            best_possible_job =
              if citizen.education > 0 do
                # [3,2,1,0]
                levels = Enum.reverse(0..citizen.education)

                Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
                  if acc.jobs[level_to_check] > 0,
                    do: {:halt, job_acc},
                    else: {:cont, job_acc - 1}
                end)
              else
                if acc.jobs[0] > 0, do: 0, else: -1
              end

            job_gap = citizen.education - best_possible_job

            # citizen will look if there is no housing, if there is no best possible job, and if gap > 1
            will_citizen_look = best_possible_job < 0 || acc.housing < 1 || job_gap > 1

            # add to citizens_looking array
            citizens_looking =
              if will_citizen_look,
                do: [citizen | acc.citizens_looking],
                else: acc.citizens_looking

            # give citizen money based on job
            # take away based on house price

            # function to spawn children
            # function to look for education if have money

            updated_jobs =
              if best_possible_job > -1,
                do: Map.update!(acc.jobs, best_possible_job, &(&1 - 1)),
                else: acc.jobs

            # also kill based on roads / random chance
            if citizen.age > 36500, do: kill_citizen(citizen)

            # return this
            %{
              jobs: updated_jobs,
              tax: 1 + best_possible_job + acc.tax,
              housing: acc.housing - 1,
              daily_cost: daily_cost,
              citizens_looking: citizens_looking
            }
          end
        )

      results
    else
      %{
        jobs: available_jobs,
        tax: 0,
        housing: available_housing,
        daily_cost: daily_cost,
        citizens_looking: []
      }
    end
  end

  def calculate_housing(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)

    Enum.reduce(Details.buildables().housing, 0, fn {building_type, building_options}, acc ->
      # get fits, multiply by number of buildings
      acc + building_options.fits * Map.get(city_preloaded.detail, building_type)
    end)
  end

  def calculate_jobs(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)
    empty_jobs_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    Enum.reduce(Details.buildables(), empty_jobs_map, fn category, acc ->
      {categoryName, buildings} = category

      if categoryName != :housing && categoryName != :civic do
        acc
        |> Enum.map(fn {job_level, jobs} ->
          {job_level,
           jobs +
             Enum.reduce(buildings, 0, fn {building_type, building_options}, acc2 ->
               if building_options.job_level == job_level do
                 acc2 + building_options.jobs * Map.get(city_preloaded.detail, building_type)
               else
                 acc2
               end
             end)}
        end)
        |> Enum.into(%{})
      else
        acc
      end
    end)
  end

  def calculate_daily_cost(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)
    # for each element in the details struct options
    Enum.reduce(MayorGame.City.Details.buildables(), 0, fn category, acc ->
      {_categoryName, buildings} = category

      acc +
        Enum.reduce(buildings, 0, fn {building_type, building_options}, acc2 ->
          acc2 + building_options.ongoing_price * Map.get(city_preloaded.detail, building_type)
        end)
    end)
  end

  def preload_city_check(%MayorGame.City.Info{} = city) do
    if !Ecto.assoc_loaded?(city.detail) do
      city |> MayorGame.Repo.preload([:citizens, :user, :detail])
    else
      city
    end
  end
end
