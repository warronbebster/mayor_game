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

    IO.inspect(cities)

    for city <- cities do
      IO.puts(city.title)

      if List.first(city.citizens) != nil do
        # ok lol so this just returns [5,5,5,5,5] i think
        value_per_citizen = for citizen <- city.citizens, do: 5
        # some function here to determine tax value

        # if it's not empty
        tax_income = Enum.reduce(value_per_citizen, fn x, acc -> x + acc end)
        # could I do the whole thing with a reduce on city.citizens?

        case MayorGame.City.update_details(city.detail, %{
               city_treasury: city.detail.city_treasury + tax_income
             }) do
          {:ok, _updated_details} ->
            IO.puts("success bringing in taxes")

          {:error, err} ->
            IO.inspect(err)
        end
      end
    end

    # this grabs head of citizens list (hd) then preloads details
    # IO.inspect(MayorGame.Repo.preload(hd(citizens).info, :detail))

    # IO.inspect(citizens)

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
end
