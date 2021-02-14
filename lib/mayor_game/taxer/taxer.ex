defmodule MayorGame.Taxer do
  use GenServer, restart: :permanent

  def val(pid) do
    GenServer.call(pid, :val)
  end

  def cities(pid) do
    # call gets stuff back
    GenServer.call(pid, :cities)
  end

  def start_link(initial_val) do
    # starts link based on this file
    # triggers init function in module
    GenServer.start_link(__MODULE__, initial_val)
  end

  # when GenServer.call is called:
  def handle_call(:cities, _from, val) do
    cities = MayorGame.City.list_cities()

    # I guess this is where you could do all the citizen switching?
    # would this be where you can also pubsub over to users that are connected?
    # send back to the thingy?
    {:reply, cities, val}
  end

  def handle_call(:val, _from, val) do
    {:reply, val, val}
  end

  def init(initial_val) do
    # send message :tick to self process after 1000ms
    Process.send_after(self(), :tax, 5000)

    # returns ok tuple when u start
    {:ok, initial_val}
  end

  # when tick is sent
  def handle_info(:tax, val) do
    cities = MayorGame.City.list_cities_preload()

    for city <- cities do
      operating_cost =
        Enum.reduce(MayorGame.City.Details.detail_options(), 0, fn category, acc ->
          calculate_cost(category, acc, city.detail)
        end)

      # check amount

      # then calculate income to the city
      # if there are citizens
      if List.first(city.citizens) != nil do
        # eventually i could use Stream instead of Enum if cities is loooooong
        tax_income =
          Enum.reduce(city.citizens, 0, fn citizen, acc -> calculate_taxes(citizen, acc) end)

        # check here for if tax_income - operating_cost is less than zero
        case MayorGame.City.update_details(city.detail, %{
               city_treasury: city.detail.city_treasury + tax_income - operating_cost
             }) do
          {:ok, _updated_details} ->
            IO.puts("success bringing in taxes")

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

  def calculate_taxes(citizen, acc \\ 0) do
    # more complicated stuff to come here
    citizen.money + acc
  end

  def calculate_cost(category, acc \\ 0, detail) do
    # more complicated stuff to come here
    {_categoryName, buildings} = category

    acc +
      Enum.reduce(buildings, 0, fn {building_type, building_options}, acc2 ->
        acc2 + building_options.ongoing_price * Map.get(detail, building_type)
      end)
  end

  #   # first, calculate operating costs
  #   for {category, buildings} <- MayorGame.City.Details.detail_options do
  #     for {building_type, options} <- buildings
  #     end
  #   end
end
