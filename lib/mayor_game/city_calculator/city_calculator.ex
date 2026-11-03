defmodule MayorGame.CityCalculator do
  @moduledoc """
  The game loop. Every `:tick_interval_ms` (set in config/runtime.exs) this GenServer advances the
  world by one day:

    1. loads every active city and computes its stats for the day
       (`CityHelpers.calculate_city_stats_with_drops/7` and `CityHelpers.calculate_citizen_stats/8`)
    2. writes each city's resource production/consumption and tax income
    3. settles market trades (`MarketHelpers`)
    4. resolves ongoing attacks (`CityCombat`)
    5. moves citizens between cities and records births and deaths (`CityMigrator`)
    6. increments the world's day and pollution, then broadcasts `"ping"` on `"cityPubSub"`
       so every open LiveView refreshes
  """
  use GenServer, restart: :permanent
  alias MayorGame.City.{Town, Buildable, OngoingAttacks, TownStats, ResourceStats}
  alias MayorGame.{City, CityCombat, CityHelpers, CityMigrator, MarketHelpers, Repo, Rules}
  import Ecto.Query

  def start_link(world_id) do
    if is_nil(City.get_world(world_id)), do: City.create_world(%{day: 0, pollution: 0})

    GenServer.start_link(__MODULE__, world_id, name: __MODULE__)
  end

  @impl true
  def init(world_id) do
    Process.send_after(self(), :tick, 500)

    {:ok,
     %{
       world_id: world_id,
       in_dev: Application.get_env(:mayor_game, :env) == :dev,
       buildables_map: %{
         buildables_flat: Buildable.buildables_flat(),
         buildables: Buildable.buildables(),
         buildables_kw_list: Buildable.buildables_kw_list(),
         buildables_list: Buildable.buildables_list(),
         buildables_ordered: Buildable.buildables_ordered()
       }
     }}
  end

  @impl true
  def handle_info(:tick, state) do
    started_at = System.monotonic_time(:millisecond)

    world = run_tick(state)

    IO.puts(
      "#{DateTime.utc_now()} | Calculator Tick | Time: #{System.monotonic_time(:millisecond) - started_at} ms" <>
        " | Day #{world.day} | Pollution: #{world.pollution}"
    )

    Process.send_after(self(), :tick, Application.get_env(:mayor_game, :tick_interval_ms, 5000))

    {:noreply, state}
  end

  @doc """
  Runs one day of the game and returns the updated `%World{}`.
  """
  def run_tick(%{world_id: world_id, buildables_map: buildables_map, in_dev: in_dev}) do
    world = City.get_world!(world_id)
    {:ok, now} = DateTime.now("Etc/UTC")
    season = Rules.season_from_day(world.day)
    # should we tie pollution effect to RNG?
    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)
    # citizens get educated every 100 days (every 5 in dev)
    time_to_learn = rem(world.day, if(in_dev, do: 5, else: 100)) == 0

    cities =
      CityHelpers.prepare_cities(now, world.day, in_dev)
      |> Enum.map(fn city ->
        # %TownStats{}: production, consumption, jobs etc. for the day
        stats =
          CityHelpers.calculate_city_stats_with_drops(
            city,
            world,
            pollution_ceiling,
            season,
            buildables_map,
            in_dev,
            time_to_learn
          )

        # %TownMigrationStatistics{}: which citizens stay, look to move, are born or die
        migration_stats =
          CityHelpers.calculate_citizen_stats(
            city,
            stats,
            world,
            pollution_ceiling,
            season,
            buildables_map,
            in_dev,
            time_to_learn
          )

        city |> Map.merge(stats) |> Map.merge(migration_stats)
      end)

    write_resources(cities)

    MarketHelpers.calculate_market_trades(Map.new(cities, &{&1.id, &1}))

    resolve_attacks(cities)

    if cities != [] do
      cities
      |> Enum.shuffle()
      |> CityMigrator.migrate()
      |> CityMigrator.persist(cities, world.day)
    end

    # city.pollution is the pollution each city produced on the previous tick
    new_world_pollution = cities |> Enum.map(& &1.pollution) |> Enum.sum()

    {:ok, updated_world} =
      City.update_world(world, %{
        day: world.day + 1,
        pollution: max(world.pollution + new_world_pollution, 0)
      })

    # every open LiveView subscribes to this and refreshes
    MayorGameWeb.Endpoint.broadcast!("cityPubSub", "ping", updated_world)

    updated_world
  end

  defp write_resources(cities) do
    cities
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk ->
      Repo.checkout(
        fn ->
          Enum.each(chunk, fn city ->
            try do
              from(t in Town,
                where: t.id == ^city.id,
                update: [
                  inc:
                    ^(Enum.map(
                        ResourceStats.resource_list(),
                        # max() prevents incrementing down into negatives, which would violate a DB constraint
                        &{&1,
                         city
                         |> net_production(&1)
                         |> max(1 - (city |> TownStats.getResource(&1) |> ResourceStats.getStock()))}
                      )
                      |> Keyword.merge(treasury: city |> net_production(:money) |> max(1 - city.treasury))),
                  set: [pollution: ^net_production(city, :pollution)]
                ]
              )
              |> Repo.update_all([])
            rescue
              e in Postgrex.Error ->
                IO.inspect(e)
                IO.inspect(city.title <> " error in city_calculator")
            end
          end)
        end,
        timeout: 6_000_000
      )
    end)
  end

  # each ongoing attack fires up to attack_count missiles per day, limited by the attacker's daily_strikes.
  # cities set to retaliate fire back at their attackers.
  defp resolve_attacks(cities) do
    attacks = OngoingAttacks |> Repo.all() |> Repo.preload([:attacking, :attacked])

    strikes_left =
      cities
      |> Enum.map(&{&1.id, net_production(&1, :daily_strikes)})
      |> Enum.filter(fn {_id, strikes} -> strikes > 0 end)
      |> Map.new()

    Enum.reduce(attacks, strikes_left, fn attack, acc ->
      attacker_id = attack.attacking.id
      defender_id = attack.attacked.id

      if Map.get(acc, attacker_id, 0) > 0 do
        strikes = min(attack.attack_count, acc[attacker_id])
        CityCombat.attack_city(attack.attacked, attacker_id, strikes)
        acc = Map.update!(acc, attacker_id, &(&1 - strikes))

        if attack.attacked.retaliate && Map.get(acc, defender_id, 0) > 0 do
          retaliation_strikes = min(attack.attack_count, acc[defender_id])
          CityCombat.attack_city(attack.attacking, defender_id, retaliation_strikes)
          Map.update!(acc, defender_id, &(&1 - retaliation_strikes))
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp net_production(city, resource), do: city |> TownStats.getResource(resource) |> ResourceStats.getNetProduction()
end
