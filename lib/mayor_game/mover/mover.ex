defmodule MayorGame.Mover do
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
    Process.send_after(self(), :citizens, 5000)

    # returns ok tuple when u start
    {:ok, initial_val}
  end

  # when tick is sent
  def handle_info(:citizens, val) do
    # ok so here I grab citizens
    # maybe should write function that grabs a single citizen and preloads its :info (city) and then preloads its :detail
    # huh ok this function does not exist lol
    # citizens = MayorGame.City.list_citizens_preload()
    citizens = MayorGame.City.list_citizens()

    # this grabs head of citizens list (hd) then preloads details
    # IO.inspect(MayorGame.Repo.preload(hd(citizens).info, :detail))

    # IO.inspect(citizens)

    # send info to liveView process that manages frontEnd
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "ping",
      val
    )

    # recurse, do it again
    Process.send_after(self(), :citizens, 5000)

    # I guess this is where you could do all the citizen switching?
    # would this be where you can also pubsub over to users that are connected?
    # return noreply and val
    # increment val
    {:noreply, val + 1}
  end
end
