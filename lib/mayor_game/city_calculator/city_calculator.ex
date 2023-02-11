defmodule MayorGame.CityCalculator do
  use GenServer, restart: :permanent
  alias MayorGame.City.Buildable
  alias MayorGame.City.{Town, Citizens}
  alias MayorGame.{City, CityHelpers, Repo}
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
      buildables_kw_list: Buildable.buildables_kw_list(),
      buildables: Buildable.buildables(),
      buildables_list: Buildable.buildables_list(),
      buildables_ordered: Buildable.buildables_ordered(),
      buildables_ordered_flat: Buildable.buildables_ordered_flat(),
      sorted_buildables: Buildable.sorted_buildables(),
      empty_buildable_map: Buildable.empty_buildable_map()
    }

    IO.puts('init')
    # initial_val is 1 here, set in application.ex then started with start_link

    game_world = City.get_world!(initial_world)
    IO.inspect(game_world)

    # send message :tax to self process after 5000ms
    # calls `handle_info` function
    Process.send_after(self(), :tax, 2000)

    # returns ok tuple when u start
    {:ok, %{world: game_world, buildables_map: buildables_map}}
  end

  # when :tax is sent
  def handle_info(:tax, %{world: world, buildables_map: buildables_map} = _sent_map) do
    cities = City.list_cities_preload()

    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    db_world = City.get_world!(1)

    IO.puts(
      "day: " <>
        to_string(db_world.day) <>
        " | pollution: " <>
        to_string(db_world.pollution) <> " | —————————————————————————————————————————————"
    )

    season =
      cond do
        rem(world.day, 365) < 91 -> :winter
        rem(world.day, 365) < 182 -> :spring
        rem(world.day, 365) < 273 -> :summer
        true -> :fall
      end

    # :eprof.start_profiling([self()])

    leftovers =
      cities
      # |> Flow.from_enumerable(max_demand: 100)
      |> Enum.map(fn city ->
        # result here is a %Town{} with stats calculated
        CityHelpers.calculate_city_stats(
          city,
          db_world,
          pollution_ceiling,
          season,
          buildables_map
        )
      end)

    #

    # citizens_looking =
    #   city_with_stats2.housed_unemployed_citizens ++
    #     city_with_stats2.housed_employed_looking_citizens

    # housing_slots = city_with_stats2.housing_left

    # + length(city_with_stats2.housed_unemployed_citizens) + length(city_with_stats2.housed_employed_looking_citizens)

    # All_cities_new = just  leftovers

    citizens_too_old = List.flatten(Enum.map(leftovers, fn city -> city.old_citizens end))

    # citizens_looking =
    #   List.flatten(
    #     Enum.map(leftovers, fn city ->
    #       city.housed_unemployed_citizens ++ city.housed_employed_looking_citizens
    #     end)
    #   )

    citizens_polluted = List.flatten(Enum.map(leftovers, fn city -> city.polluted_citizens end))

    citizens_to_reproduce =
      List.flatten(Enum.map(leftovers, fn city -> city.reproducing_citizens end))

    # unhoused_citizens = List.flatten(Enum.map(leftovers, fn city -> city.unhoused_citizens end))
    new_world_pollution = Enum.sum(Enum.map(leftovers, fn city -> city.pollution end))
    # total_slots = Enum.sum(Enum.map(leftovers, fn city -> city.housing_left end))

    citizens_learning = %{
      1 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[1] end)),
      2 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[2] end)),
      3 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[3] end)),
      4 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[4] end)),
      5 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[5] end))
    }

    leftovers
    |> Enum.sort_by(& &1.id)
    |> Enum.chunk_every(200)
    |> Enum.each(fn chunk ->
      # town_ids = Enum.map(chunk, fn city -> city.id end)
      Enum.each(chunk, fn city ->
        from(t in Town,
          where: t.id == ^city.id,
          update: [
            inc: [
              treasury: ^city.income - ^city.daily_cost,
              steel: ^city.new_steel,
              missiles: ^city.new_missiles,
              sulfur: ^city.new_sulfur,
              gold: ^city.new_gold,
              uranium: ^city.new_uranium,
              shields: ^city.new_shields
            ],
            set: [
              citizen_count: ^city.citizen_count,
              pollution: ^city.pollution
            ]
          ]
        )
        |> Repo.update_all([])
      end)
    end)

    # MULTI CHANGESET EDUCATE ——————————————————————————————————————————————————— DB UPDATE

    citizens_learning
    |> Enum.each(fn {level, list} ->
      list
      |> Enum.sort_by(& &1.id)
      |> Enum.chunk_every(200)
      |> Enum.each(fn chunk ->
        # potentially use list.keysort instead of sort_by for perf reasons
        citizen_ids = chunk |> Enum.map(fn citizen -> citizen.id end)

        town_ids = chunk |> Enum.map(fn citizen -> citizen.town_id end) |> Enum.sort()

        from(c in Citizens, where: c.id in ^citizen_ids)
        |> Repo.update_all(inc: [education: 1])

        from(t in Town,
          where: t.id in ^town_ids,
          update: [push: [logs: ^"A citizen graduated to level #{level}"]]
        )
        |> Repo.update_all([])
      end)
    end)

    # end

    # end)

    # MULTI CHANGESET AGE

    Repo.update_all(MayorGame.City.Citizens, inc: [age: 1])

    # MULTI CHANGESET KILL OLD CITIZENS ——————————————————————————————————————————————————— DB UPDATE

    citizens_too_old
    |> Enum.sort_by(& &1.id)
    |> Enum.chunk_every(200)
    |> Enum.each(fn chunk ->
      citizen_ids = chunk |> Enum.map(fn citizen -> citizen.id end)

      town_ids = chunk |> Enum.map(fn citizen -> citizen.town_id end) |> Enum.sort()

      from(c in Citizens, where: c.id in ^citizen_ids)
      |> Repo.delete_all()

      from(t in Town,
        where: t.id in ^town_ids,
        update: [push: [logs: "A citizen died from old age. RIP"]]
      )
      |> Repo.update_all([])
    end)

    # end)

    # MULTI KILL POLLUTED CITIZENS ——————————————————————————————————————————————————— DB UPDATE
    citizens_polluted
    |> Enum.sort_by(&elem(&1, 0).id)
    |> Enum.chunk_every(200)
    |> Enum.each(fn chunk ->
      citizen_ids = chunk |> Enum.map(fn citizen -> citizen.id end)

      town_ids = chunk |> Enum.map(fn citizen -> citizen.town_id end) |> Enum.sort()

      from(c in Citizens, where: c.id in ^citizen_ids)
      |> Repo.delete_all()

      from(t in Town,
        where: t.id in ^town_ids,
        update: [push: [logs: "A citizen died from pollution. RIP"]]
      )
      |> Repo.update_all([])
    end)

    # MULTI REPRODUCE ——————————————————————————————————————————————————— DB UPDATE

    now_utc = DateTime.truncate(DateTime.utc_now(), :second)

    citizens_to_reproduce
    |> Enum.sort_by(& &1.id)
    |> Enum.chunk_every(200)
    |> Enum.each(fn chunk ->
      births =
        Enum.map(chunk, fn citizen ->
          %{
            town_id: citizen.town_id,
            age: 0,
            education: 0,
            has_job: false,
            last_moved: db_world.day,
            name: Faker.Person.name(),
            preferences: CityHelpers.create_citizen_preference_map(),
            inserted_at: now_utc,
            updated_at: now_utc
          }
        end)

      if births != [] do
        Repo.insert_all(Citizens, births)
      end

      town_ids =
        chunk |> Enum.sort_by(& &1.town_id) |> Enum.map(fn citizen -> citizen.town_id end)

      from(t in Town,
        where: t.id in ^town_ids,
        update: [push: [logs: "A child was born"]]
      )
      |> Repo.update_all([])
    end)

    updated_pollution =
      if db_world.pollution + new_world_pollution < 0 do
        0
      else
        db_world.pollution + new_world_pollution
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
    Process.send_after(self(), :tax, 2000)

    # returns this to whatever calls ?
    {:noreply, %{world: updated_world, buildables_map: buildables_map}}
  end

  def update_logs(log, existing_logs) do
    updated_log = if !is_nil(existing_logs), do: [log | existing_logs], else: [log]

    # updated_log = [log | existing_logs]

    if length(updated_log) > 50 do
      updated_log |> Enum.take(50)
    else
      updated_log
    end
  end
end
