defmodule MayorGame.CityCalculator do
  use GenServer, restart: :permanent
  alias MayorGame.CityCombat
  alias MayorGame.City.{Town, Buildable, OngoingAttacks, TownStatistics, ResourceStatistics, Citizens}
  alias MayorGame.{City, CityHelpers, Repo, Rules}
  import Ecto.Query

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
    buildables_map = %{
      buildables_flat: Buildable.buildables_flat(),
      buildables: Buildable.buildables(),
      buildables_kw_list: Buildable.buildables_kw_list(),
      buildables_list: Buildable.buildables_list(),
      buildables_ordered: Buildable.buildables_ordered()
    }

    in_dev = Application.get_env(:mayor_game, :env) == :dev

    IO.puts('init calculator')
    # initial_val is 1 here, set in application.ex then started with start_link

    game_world = City.get_world!(initial_world)

    # send message :tax to self process after 5000ms
    # calls `handle_info` function
    Process.send_after(self(), :tax, 500)

    # returns ok tuple when u start
    {:ok, %{world: game_world, buildables_map: buildables_map, in_dev: in_dev}}
  end

  # when :tax is sent
  def handle_info(
        :tax,
        %{world: world, buildables_map: buildables_map, in_dev: in_dev} = _sent_map
      ) do
    # profiling
    {:ok, datetime_pre} = DateTime.now("Etc/UTC")

    # :eprof.start_profiling([self()])

    # filter obviously ghost cities
    # add pollution check. It is possible to trick this check with a city reset, and by building road and park without building housing
    cities = CityHelpers.prepare_cities(datetime_pre, world.day)

    # should we tie pollution effect to RNG?
    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    db_world = City.get_world!(1)

    season = Rules.season_from_day(world.day)

    leftovers =
      cities
      # |> Flow.from_enumerable(max_demand: 100)
      |> Enum.map(fn city ->
        # keeping city for citizens_blob
        city
        |> Map.merge(
          # result here is a %Town{} with stats calculated
          CityHelpers.calculate_city_stats_with_drops(
            city,
            db_world,
            pollution_ceiling,
            season,
            buildables_map,
            in_dev,
            false
          )
        )
      end)

    new_world_pollution =
      leftovers
      |> Enum.map(fn city -> city.pollution end)
      |> Enum.sum()

    CityHelpers.calculate_market_trades(leftovers |> Enum.map(fn city -> {city.id, city} end) |> Enum.into(%{}))

    leftovers
    # |> Enum.sort_by(& &1.id)
    |> Enum.chunk_every(200)
    |> Enum.each(fn chunk ->
      Repo.checkout(
        fn ->
          # town_ids = Enum.map(chunk, fn city -> city.id end)
          Enum.each(chunk, fn city ->
            from(t in Town,
              where: t.id == ^city.id,
              update: [
                inc: [
                  treasury:
                    ^(city
                      |> TownStatistics.getResource(:money)
                      |> ResourceStatistics.getNetProduction()),
                  missiles:
                    ^(city
                      |> TownStatistics.getResource(:missiles)
                      |> ResourceStatistics.getNetProduction()),
                  shields:
                    ^(city
                      |> TownStatistics.getResource(:shields)
                      |> ResourceStatistics.getNetProduction()),
                  steel:
                    ^(city
                      |> TownStatistics.getResource(:steel)
                      |> ResourceStatistics.getNetProduction()),
                  sulfur:
                    ^(city
                      |> TownStatistics.getResource(:sulfur)
                      |> ResourceStatistics.getNetProduction()),
                  gold:
                    ^(city
                      |> TownStatistics.getResource(:gold)
                      |> ResourceStatistics.getNetProduction()),
                  uranium:
                    ^(city
                      |> TownStatistics.getResource(:uranium)
                      |> ResourceStatistics.getNetProduction()),
                  stone:
                    ^(city
                      |> TownStatistics.getResource(:stone)
                      |> ResourceStatistics.getNetProduction()),
                  wood:
                    ^(city
                      |> TownStatistics.getResource(:wood)
                      |> ResourceStatistics.getNetProduction()),
                  fish:
                    ^(city
                      |> TownStatistics.getResource(:fish)
                      |> ResourceStatistics.getNetProduction()),
                  oil:
                    ^(city
                      |> TownStatistics.getResource(:oil)
                      |> ResourceStatistics.getNetProduction()),
                  salt:
                    ^(city
                      |> TownStatistics.getResource(:salt)
                      |> ResourceStatistics.getNetProduction()),
                  lithium:
                    ^(city
                      |> TownStatistics.getResource(:lithium)
                      |> ResourceStatistics.getNetProduction()),
                  water:
                    ^(city
                      |> TownStatistics.getResource(:water)
                      |> ResourceStatistics.getNetProduction()),
                  cows:
                    ^(city
                      |> TownStatistics.getResource(:cows)
                      |> ResourceStatistics.getNetProduction()),
                  produce:
                    ^(city
                      |> TownStatistics.getResource(:produce)
                      |> ResourceStatistics.getNetProduction()),
                  rice:
                    ^(city
                      |> TownStatistics.getResource(:rice)
                      |> ResourceStatistics.getNetProduction()),
                  food:
                    ^(city
                      |> TownStatistics.getResource(:food)
                      |> ResourceStatistics.getNetProduction()),
                  grapes:
                    ^(city
                      |> TownStatistics.getResource(:grapes)
                      |> ResourceStatistics.getNetProduction()),
                  bread:
                    ^(city
                      |> TownStatistics.getResource(:bread)
                      |> ResourceStatistics.getNetProduction()),
                  wheat:
                    ^(city
                      |> TownStatistics.getResource(:wheat)
                      |> ResourceStatistics.getNetProduction()),
                  meat:
                    ^(city
                      |> TownStatistics.getResource(:meat)
                      |> ResourceStatistics.getNetProduction())
                  # logs—————————
                ],
                set: [
                  pollution:
                    ^(city
                      |> TownStatistics.getResource(:pollution)
                      |> ResourceStatistics.getNetProduction())
                ]
              ]
            )
            |> Repo.update_all([])

            ### Potential data conflict with migrator updates?
            ### maybe move this to migrator instead
            # if city.total_citizens < 20 do
            #   updated_citizens =
            #     Enum.map(1..:rand.uniform(3), fn _citizen ->
            #       %{
            #         "age" => 0,
            #         "town_id" => city.id,
            #         "education" => 0,
            #         "preferences" => :rand.uniform(11)
            #       }
            #     end)

            #   citizens =
            #     [updated_citizens | city.citizens_blob]
            #     |> List.flatten()
            #     |> Enum.take(
            #       city
            #       |> TownStatistics.getResource(:housing)
            #       |> ResourceStatistics.getProduction()
            #     )

            #   # IO.inspect(length(citizens), label: "citizens count")

            #   render_blob = Citizens.compress_citizen_blob(citizens, world.day)

            # from(t in Town,
            #   where: t.id == ^city.id,
            #   update: [
            #     set: [
            #       # citizens_blob: ^citizens,
            #       citizens_compressed: ^render_blob,
            #       citizen_count: ^length(citizens)
            #     ]
            #   ]
            # )
            # |> Repo.update_all([])
            # end

            # also update logs here for old deaths
            # and pollution deaths
          end)
        end,
        timeout: 6_000_000
      )
    end)

    # :eprof.stop_profiling()
    # :eprof.analyze()

    # maybe do combat here?
    # based on all the ongoing_attacks?

    attacks =
      Repo.all(OngoingAttacks)
      |> Repo.preload([:attacking, :attacked])

    valid_attackers =
      leftovers
      |> Enum.filter(fn city ->
        city |> TownStatistics.getResource(:daily_strikes) |> ResourceStatistics.getNetProduction() > 0
      end)
      |> Map.new(fn city ->
        {city.id, city |> TownStatistics.getResource(:daily_strikes) |> ResourceStatistics.getNetProduction()}
      end)

    Enum.reduce(attacks, valid_attackers, fn attack, acc ->
      # check if they have daily_strikes
      if Map.has_key?(acc, attack.attacking.id) && acc[attack.attacking.id] > 0 do
        CityCombat.attack_city(
          attack.attacked,
          attack.attacking.id,
          min(attack.attack_count, acc[attack.attacking.id])
        )

        retaliating = attack.attacked.retaliate && Map.has_key?(acc, attack.attacked.id) && acc[attack.attacked.id] > 0

        if retaliating do
          CityCombat.attack_city(
            attack.attacking,
            attack.attacked.id,
            min(attack.attack_count, acc[attack.attacked.id])
          )

          acc
          |> Map.update!(attack.attacking.id, &(&1 - min(attack.attack_count, acc[attack.attacking.id])))
          |> Map.update!(attack.attacked.id, &(&1 - min(attack.attack_count, acc[attack.attacked.id])))
        else
          acc
          |> Map.update!(attack.attacking.id, &(&1 - min(attack.attack_count, acc[attack.attacking.id])))
        end
      else
        acc
      end
    end)

    # for each attack count in attack
    # reduce those cities

    # updated_world_pollution ———————————————————————————————————————————————————————————————
    updated_pollution = max(db_world.pollution + new_world_pollution, 0)

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

    # profiling
    {:ok, datetime_post} = DateTime.now("Etc/UTC")

    IO.puts(
      (datetime_post |> DateTime.to_string()) <>
        " | Calculator Tick | Time: " <>
        to_string(DateTime.diff(datetime_post, datetime_pre, :millisecond)) <>
        " ms | Day " <>
        to_string(db_world.day) <>
        " | Pollution: " <>
        to_string(db_world.pollution)
    )

    # recurse, do it again
    Process.send_after(self(), :tax, if(in_dev, do: 5000, else: 500))

    # returns this to whatever calls ?
    {:noreply, %{world: updated_world, buildables_map: buildables_map, in_dev: in_dev}}
  end
end
