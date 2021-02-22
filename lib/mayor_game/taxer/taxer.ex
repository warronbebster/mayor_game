defmodule MayorGame.Taxer do
  use GenServer, restart: :permanent
  alias MayorGame.City
  alias MayorGame.City.Details

  def val(pid) do
    GenServer.call(pid, :val)
  end

  def cities(pid) do
    # call gets stuff back
    GenServer.call(pid, :cities)
  end

  def start_link(_initial_val) do
    # starts link based on this file
    # triggers init function in module

    # ok, for some reason, resetting the ecto repo does not like this being in start_link
    # world = MayorGame.Repo.get!(MayorGame.City.World, 0)

    GenServer.start_link(__MODULE__, 0)
  end

  # when GenServer.call is called:
  def handle_call(:cities, _from, val) do
    cities = City.list_cities()

    # I guess this is where you could do all the citizen switching?
    # would this be where you can also pubsub over to users that are connected?
    # send back to the thingy?
    {:reply, cities, val}
  end

  def handle_call(:val, _from, val) do
    {:reply, val, val}
  end

  def init(_initial_val) do
    # send message :tax to self process after 5000ms
    Process.send_after(self(), :tax, 5000)
    world = MayorGame.Repo.get!(MayorGame.City.World, 1)

    # returns ok tuple when u start
    {:ok, world.day}
  end

  # when tick is sent
  def handle_info(:tax, val) do
    cities = City.list_cities_preload()
    world = MayorGame.Repo.get!(MayorGame.City.World, 1)

    # increment day
    City.update_world(world, %{day: world.day + 1})
    IO.puts("day: " <> to_string(world.day))

    # i could switch this to an Enum.map or Stream situation
    # and get a return of cities with available housing, and citizens without housing/jobs
    # although i could also do that in DB, but would have to read/write every cycle

    # Enum.reduce(cities, 0, fn {building_type, building_options}, acc ->

    # end

    for city <- cities do
      operating_cost = calculate_daily_cost(city)

      # results look like:
      # %{jobs: available_jobs, tax: 0, housing: available_housing},
      city_calculation = calculate_per_city(city)

      # maybe build list of possible jobs and levels
      # some things are constrained, like jobs, housing.
      # but some aren't, like education (which should cost something) and entertainment
      # also housing and cost
      # and entertainment value and stuff

      # if there are citizens
      if List.first(city.citizens) != nil do
        updated_city_treasury =
          if city.detail.city_treasury + city_calculation.tax - operating_cost < 0 do
            # if tax income is less than operating cost
            # maybe some other consequences here
            0
          else
            city.detail.city_treasury + city_calculation.tax - operating_cost
          end

        # check here for if tax_income - operating_cost is less than zero
        case City.update_details(city.detail, %{
               city_treasury: updated_city_treasury
             }) do
          {:ok, _updated_details} ->
            City.update_log(
              city,
              "today's tax income:" <>
                to_string(city_calculation.tax) <>
                " operating cost: " <>
                to_string(operating_cost)
            )

          {:error, err} ->
            IO.inspect(err)
        end
      end
    end

    # send info to liveView process that manages frontEnd
    # this basically sends to every client.
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "ping",
      val
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 5000)

    # I guess this is where you could do all the citizen switching?
    # would this be where you can also pubsub over to users that are connected?
    # return noreply and val
    # increment val
    {:noreply, world.day + 1}
  end

  def calculate_per_city(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)
    # if there is a citizen
    available_housing = calculate_housing(city_preloaded)
    # returns a map of %{0 => #, 0 => #, etc}
    available_jobs = calculate_jobs(city_preloaded)

    if List.first(city_preloaded.citizens) != nil do
      results =
        Enum.reduce(
          city_preloaded.citizens,
          %{jobs: available_jobs, tax: 0, housing: available_housing},
          fn citizen, acc ->
            City.update_citizens(citizen, %{age: citizen.age + 1})

            # function to spawn children

            # function to look for education if have money

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

            # give citizen money if they have job
            # take away based on house price

            # function to look for other cities
            # first — if housing
            # if yes, then — job gap
            # if that's fine, then look at travel time — houses, roads, etc
            # basically, look for other cities, and if there isn't housing available, then DIE

            updated_jobs =
              if best_possible_job >= 0,
                do: acc.jobs |> Map.put(citizen.education, acc.jobs[best_possible_job] - 1),
                else: acc.jobs

            # kill citizen if over this age
            # should add if there are no houses + citizen has no other city option
            # also kill based on cars
            if citizen.age > 36500, do: City.delete_citizens(citizen)

            %{jobs: updated_jobs, tax: 1 + citizen.job + acc.tax, housing: acc.housing - 1}
          end
        )

      # return just the tax number
      results
    else
      %{jobs: available_jobs, tax: 0, housing: available_housing}
    end
  end

  def calculate_housing(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)

    Enum.reduce(Details.buildables().housing, 0, fn {building_type, building_options}, acc ->
      # get fits, multiply by number of buildings
      acc + building_options.fits * Map.get(city_preloaded.detail, building_type)
    end)
  end

  # i think this needs to happen after it loops through the first time.
  # then match
  def look_for_cities(%MayorGame.City.Citizens{} = citizen, job_gap) do
    # Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
    #   if acc.jobs[level_to_check] > 0,
    #     do: {:halt, job_acc},
    #     else: {:cont, job_acc - 1}
    # end)
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
