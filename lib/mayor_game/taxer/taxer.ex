defmodule MayorGame.Taxer do
  use GenServer, restart: :permanent
  alias MayorGame.City

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

  def init(initial_val) do
    # send message :tax to self process after 5000ms
    Process.send_after(self(), :tax, 5000)

    # returns ok tuple when u start
    {:ok, initial_val}
  end

  # when tick is sent
  def handle_info(:tax, val) do
    buildables = MayorGame.City.Details.detail_buildables()
    cities = City.list_cities_preload()

    world = MayorGame.Repo.get!(MayorGame.City.World, 1)
    # increment day
    City.update_world(world, %{day: world.day + 1})
    IO.puts("day: " <> to_string(world.day))

    for city <- cities do
      operating_cost = calculate_daily_cost(city)

      # for each building in housing
      # eventually i could use Stream instead of Enum if cities is loooooong
      available_housing =
        Enum.reduce(buildables.housing, 0, fn {building_type, building_options}, acc ->
          # get fits, multiply by number of buildings
          acc + building_options.fits * Map.get(city.detail, building_type)
        end)

      # returns a map of %{0 => #, 0 => #, etc}
      available_jobs = calculate_jobs(city)

      tax_income = calculate_taxes(city)

      # maybe build list of possible jobs and levels
      # some things are constrained, like jobs, housing.
      # but some aren't, like education (which should cost something) and entertainment
      # also housing and cost
      # and entertainment value and stuff

      # if there are citizens
      if List.first(city.citizens) != nil do
        updated_city_treasury =
          if city.detail.city_treasury + tax_income - operating_cost < 0 do
            0
          else
            city.detail.city_treasury + tax_income - operating_cost
          end

        # check here for if tax_income - operating_cost is less than zero
        case City.update_details(city.detail, %{
               city_treasury: updated_city_treasury
             }) do
          {:ok, _updated_details} ->
            City.update_log(
              city,
              "today's tax income:" <>
                to_string(tax_income) <>
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
    {:noreply, val + 1}
  end

  def calculate_taxes(%MayorGame.City.Info{} = city) do
    # if there is a citizen
    if List.first(city.citizens) != nil do
      Enum.reduce(city.citizens, 0, fn citizen, acc ->
        City.update_citizens(citizen, %{age: citizen.age + 1})

        # function to spawn children

        # function to look for other cities

        # kill citizen if over this age
        # should add if there are no houses + citizen has no other city option
        if citizen.age > 36500, do: City.delete_citizens(citizen)

        1 + citizen.job + acc
      end)
    else
      0
    end
  end

  def calculate_jobs(%MayorGame.City.Info{} = city) do
    empty_jobs_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    Enum.reduce(MayorGame.City.Details.detail_buildables(), empty_jobs_map, fn category, acc ->
      {categoryName, buildings} = category

      if categoryName != :housing && categoryName != :civic do
        acc
        |> Enum.map(fn {job_level, jobs} ->
          {job_level,
           jobs +
             Enum.reduce(buildings, 0, fn {building_type, building_options}, acc2 ->
               if building_options.job_level == job_level do
                 acc2 + building_options.jobs * Map.get(city.detail, building_type)
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
    # for each element in the details struct options
    Enum.reduce(MayorGame.City.Details.detail_buildables(), 0, fn category, acc ->
      {_categoryName, buildings} = category

      acc +
        Enum.reduce(buildings, 0, fn {building_type, building_options}, acc2 ->
          acc2 + building_options.ongoing_price * Map.get(city.detail, building_type)
        end)
    end)
  end
end
