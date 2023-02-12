defmodule MayorGame.CityMigrator do
  use GenServer, restart: :permanent
  alias MayorGame.City.Buildable
  alias MayorGame.City.{Town, Citizens}
  alias MayorGame.{City, CityHelpers, Repo}
  import Ecto.Query

  def start_link(initial_val) do
    IO.puts('start_city_migrator_link')
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

    IO.puts('init migrator')
    # initial_val is 1 here, set in application.ex then started with start_link

    game_world = City.get_world!(initial_world)

    # send message :tax to self process after
    # calls `handle_info` function
    Process.send_after(self(), :tax, 10000)

    # returns ok tuple when u start
    {:ok, %{world: game_world, buildables_map: buildables_map}}
  end

  # when :tax is sent
  def handle_info(:tax, %{world: world, buildables_map: buildables_map} = _sent_map) do
    # filter for
    cities = City.list_cities_preload() |> Enum.filter(fn city -> city.citizen_count > 20 end)
    # cities_count = Enum.count(cities)

    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    db_world = City.get_world!(1)

    IO.puts("MOVED————————————————————————————————————————————")

    season =
      cond do
        rem(world.day, 365) < 91 -> :winter
        rem(world.day, 365) < 182 -> :spring
        rem(world.day, 365) < 273 -> :summer
        true -> :fall
      end

    cities_list = Enum.shuffle(cities)

    # :eprof.start_profiling([self()])

    leftovers =
      cities_list
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

    citizens_looking =
      List.flatten(
        Enum.map(leftovers, fn city ->
          city.housed_unemployed_citizens ++ city.housed_employed_looking_citizens
        end)
      )

    unhoused_citizens = List.flatten(Enum.map(leftovers, fn city -> city.unhoused_citizens end))
    # new_world_pollution = Enum.sum(Enum.map(leftovers, fn city -> city.pollution end))
    total_slots = Enum.sum(Enum.map(leftovers, fn city -> city.housing_left end))

    housing_slots = Enum.map(leftovers, fn city -> {city.id, city.housing_left} end) |> Map.new()

    sprawl_max = Enum.max(Enum.map(leftovers, fn city -> city.sprawl end))
    pollution_max = Enum.max(Enum.map(leftovers, fn city -> city.pollution end))
    pollution_min = Enum.min(Enum.map(leftovers, fn city -> city.pollution end))
    pollution_spread = pollution_max - pollution_min
    fun_max = Enum.max(Enum.map(leftovers, fn city -> city.fun end))
    health_max = Enum.max(Enum.map(leftovers, fn city -> city.health end))
    health_min = Enum.min(Enum.map(leftovers, fn city -> city.health end))
    health_spread = health_max - health_min

    slotted_cities_by_id =
      leftovers
      |> Enum.map(fn city ->
        normalize_city(
          city,
          fun_max,
          health_spread,
          pollution_spread,
          sprawl_max
        )
      end)
      |> Map.new(fn city ->
        {city.id, city |> Map.put(:updated_citizens, city.city.housed_employed_staying_citizens)}
      end)

    updated_citizens_by_id =
      leftovers
      |> Map.new(fn city -> {city.id, city.housed_employed_staying_citizens} end)

    # for each city
    # add an aempty list
    # first put staying citizens
    # then push other citizens into it
    # housed_unemployed_citizens: [],
    # housed_employed_staying_citizens: [],
    # housed_employed_looking_citizens: [],
    # unhoused_citizens: [],

    # :eprof.stop_profiling()
    # :eprof.analyze()

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 1: MOVE CITIZENS PER JOB LEVEL
    # ——————————————————————————————————————————————————————————————————————————————————

    level_slots =
      Map.new(0..5, fn x -> {x, %{normalized_cities: [], total_slots: 0, slots_expanded: []}} end)

    # sets up empty map for below function
    # SHAPE OF BELOW:
    # %{
    #   1: %{normalized_cities: [
    #     {city_normalized, # of slots}, {city_normalized, # of slots}
    #   ],
    #     total_slots: int,
    #     slots_expanded: list of slots
    #   }
    # }
    # all_cities_by_id = maybe make a map here of city in all_cities_new and their id
    # or all_cities_new might already be that, by index
    # or the map is just of the ones with housing slots (e.g. in housing_slots)
    # all_cities_by_id =
    #   leftovers
    #   |> Map.new(fn city -> {city.id, city} end)

    # NO FLOW

    # housing_slots is a list of {city, number of slots}
    # try FLOW here with a partition + reduce
    # do a bunch of the housing calcs with ETS? instead of mapping over a map accumulator, put it in ets and manipulate it there?
    job_and_housing_slots_normalized =
      Enum.reduce(
        housing_slots,
        %{level_slots: level_slots, total_slots_left: total_slots},
        fn {normalized_city_id, housing_slots_count}, acc ->
          slots_per_level =
            Enum.reduce(
              slotted_cities_by_id[normalized_city_id].jobs,
              %{housing_slots_left: housing_slots_count},
              fn {level, count}, acc2 ->
                if acc2.housing_slots_left > 0 do
                  level_slots_count = min(count, acc2.housing_slots_left)

                  acc2
                  |> Map.update!(
                    :housing_slots_left,
                    &(&1 - level_slots_count)
                  )
                  |> Map.put(level, {normalized_city_id, level_slots_count})
                else
                  acc2
                  |> Map.put(level, {normalized_city_id, 0})
                end
              end
            )
            |> Map.drop([:housing_slots_left])

          # each value is [{city, count}]
          # slots_taken_w_job = Enum.sum(Map.values(slots_per_level))
          slots_taken_w_job = Enum.sum(Keyword.values(Map.values(slots_per_level)))

          # for each level in slots_per_level
          #
          level_results =
            Enum.map(0..5, fn x ->
              {x,
               %{
                 normalized_cities: acc.level_slots[x].normalized_cities ++ [slots_per_level[x]],
                 total_slots: acc.level_slots[x].total_slots + elem(slots_per_level[x], 1),
                 slots_expanded:
                   acc.level_slots[x].slots_expanded ++
                     Enum.map(1..elem(slots_per_level[x], 1), fn _ -> normalized_city_id end)
               }}
            end)
            |> Enum.into(%{})

          %{
            level_slots: level_results,
            total_slots_left: acc.total_slots_left - slots_taken_w_job
          }
        end
      )

    citizens_split =
      Map.new(0..5, fn x ->
        {x,
         Enum.split(
           Enum.filter(citizens_looking, fn cit -> cit.education == x end),
           job_and_housing_slots_normalized.level_slots[x].total_slots
         )}
      end)

    preferred_locations_by_level =
      Map.new(0..5, fn level ->
        {level,
         Enum.reduce(
           elem(citizens_split[level], 0),
           %{
             choices: [],
             slots:
               job_and_housing_slots_normalized.level_slots[level].normalized_cities
               |> Enum.into(%{})
           },
           fn citizen, acc ->
             chosen_city =
               Enum.reduce(acc.slots, %{chosen_id: 0, top_score: -1}, fn {city_id, count}, acc2 ->
                 score =
                   if count > 0 do
                     Float.round(
                       citizen_score(
                         citizen.preferences,
                         citizen.education,
                         slotted_cities_by_id[city_id]
                       ),
                       4
                     )
                   else
                     0
                   end

                 if score > acc2.top_score do
                   %{
                     chosen_id: city_id,
                     top_score: score
                   }
                 else
                   acc2
                 end
               end)

             updated_slots =
               if acc.slots != %{} && chosen_city.chosen_id != 0 do
                 if acc.slots[chosen_city.chosen_id] > 0 do
                   Map.update!(acc.slots, chosen_city.chosen_id, &(&1 - 1))
                 else
                   Map.drop(acc.slots, [chosen_city.chosen_id])
                 end
               else
                 acc.slots
               end

             %{
               choices:
                 if chosen_city.chosen_id == 0 do
                   acc.choices
                 else
                   acc.choices ++ [{citizen, chosen_city.chosen_id}]
                 end,
               slots: updated_slots
             }
           end
         )}
      end)

    looking_but_not_in_job_race =
      Enum.reduce(citizens_split, [], fn {_k, v}, acc ->
        acc ++ elem(v, 1)
      end)

    # array of citizens who are still looking, that didn't make it into the level-specific comparisons

    # MULTI CHANGESET MOVE JOB SEARCHING CITIZENS

    # MOVE CITIZENS

    updated_citizens_by_id_2 =
      Enum.reduce(0..5, updated_citizens_by_id, fn x, acc ->
        if preferred_locations_by_level[x].choices != [] do
          Enum.reduce(preferred_locations_by_level[x].choices, acc, fn {citizen, chosen_city_id},
                                                                       acc2 ->
            if citizen.town_id != chosen_city_id do
              acc2 |> Map.update!(chosen_city_id, &[citizen | &1])
            else
              acc2
            end
          end)
        else
          acc
        end
      end)

    # Enum.each(0..5, fn x ->
    #   if preferred_locations_by_level[x].choices != [] do
    #     preferred_locations_by_level[x].choices
    #     # |> Enum.sort_by(&elem(&1, 0).id)
    #     |> Enum.chunk_every(200)
    #     |> Enum.each(fn chunk ->
    #       Enum.reduce(chunk, Ecto.Multi.new(), fn {citizen, city_id}, multi ->
    #         town_from = struct(Town, slotted_cities_by_id[citizen.town_id].city)
    #         town_to = struct(Town, slotted_cities_by_id[city_id].city)

    #         # IO.inspect(slotted_cities_by_id[citizen.town_id].city)

    #         if town_from.id != town_to.id do
    #           citizen_changeset =
    #             citizen
    #             |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

    #           log_from =
    #             CityHelpers.describe_citizen(citizen) <>
    #               " has moved to " <> town_to.title

    #           log_to =
    #             CityHelpers.describe_citizen(citizen) <>
    #               " has moved from " <> town_from.title

    #           # if list is longer than 50, remove last item
    #           limited_log_from = update_logs(log_from, town_from.logs)
    #           limited_log_to = update_logs(log_to, town_to.logs)

    #           town_from_changeset =
    #             town_from
    #             |> City.Town.changeset(%{logs: limited_log_from})

    #           town_to_changeset =
    #             town_to
    #             |> City.Town.changeset(%{logs: limited_log_to})

    #           Ecto.Multi.update(multi, {:update_citizen_town, citizen.id}, citizen_changeset)
    #           |> Ecto.Multi.update({:update_town_from, citizen.id}, town_from_changeset)
    #           |> Ecto.Multi.update({:update_town_to, citizen.id}, town_to_changeset)
    #         else
    #           multi
    #         end
    #       end)
    #       |> Repo.transaction(timeout: 230_000)
    #     end)
    #   end
    # end)

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 2: MOVE CITIZENS ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    # this produces a list of cities that have been occupied
    # this could also be in ETS
    occupied_slots =
      Enum.flat_map(preferred_locations_by_level, fn {_level, preferred_locations} ->
        Enum.map(preferred_locations.choices, fn {_citizen_id, city_id} ->
          city_id

          # could also potentially move the citizens here
          # could move citizens here
          # COULD MOVE CITIZENS HERE ———————————————————————————————————
        end)
      end)

    # take housing slots, remove any city that was occupied previously
    slots_after_job_migrations =
      if housing_slots == %{} do
        %{}
      else
        Enum.reduce(occupied_slots, housing_slots, fn city_id, acc ->
          # need to find the right key, these cities are already normalized
          if is_nil(city_id) do
            acc
          else
            # key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
            Map.update!(acc, city_id, &(&1 - 1))
          end
        end)
      end

    slots_after_job_filtered =
      Enum.filter(slots_after_job_migrations, fn {_k, v} -> v > 0 end) |> Enum.into(%{})

    # SHAPE OF unhoused_locations.choices is an array of {citizen, city_id}
    preferred_locations =
      Enum.reduce(
        looking_but_not_in_job_race,
        %{choices: [], slots: slots_after_job_filtered},
        fn citizen, acc ->
          chosen_city =
            Enum.reduce(acc.slots, %{chosen_id: 0, top_score: -1}, fn {city_id, count}, acc2 ->
              score =
                if count > 0 do
                  Float.round(
                    citizen_score(
                      citizen.preferences,
                      citizen.education,
                      slotted_cities_by_id[city_id]
                    ),
                    4
                  )
                else
                  0
                end

              if score > acc2.top_score do
                %{
                  chosen_id: city_id,
                  top_score: score
                }
              else
                acc2
              end
            end)

          updated_slots =
            if acc.slots != %{} && chosen_city.chosen_id != 0 do
              if acc.slots[chosen_city.chosen_id] > 0 do
                Map.update!(acc.slots, chosen_city.chosen_id, &(&1 - 1))
              else
                Map.drop(acc.slots, [chosen_city.chosen_id])
              end
            else
              acc.slots
            end

          %{
            choices:
              if chosen_city.chosen_id == 0 do
                acc.choices
              else
                acc.choices ++ [{citizen, chosen_city.chosen_id}]
              end,
            slots: updated_slots
          }
        end
      )

    # if preferred_locations.choices != [] do
    #   preferred_locations.choices
    #   # |> Flow.from_enumerable(max_demand: 100)
    #   # |> Enum.sort_by(&elem(&1, 0).id)
    #   |> Enum.chunk_every(200)
    #   |> Enum.each(fn chunk ->
    #     Enum.reduce(chunk, Ecto.Multi.new(), fn {citizen, city_id}, multi ->
    #       town_from = struct(Town, slotted_cities_by_id[citizen.town_id].city)
    #       town_to = struct(Town, slotted_cities_by_id[city_id].city)

    #       IO.inspect(slotted_cities_by_id[city_id].city.citizens)
    #       # ok this pulls the right stuff

    #       if town_from.id != town_to.id do
    #         citizen_changeset =
    #           citizen
    #           |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

    #         log_from =
    #           CityHelpers.describe_citizen(citizen) <>
    #             " has moved to " <> town_to.title

    #         log_to =
    #           CityHelpers.describe_citizen(citizen) <>
    #             " has moved from " <> town_from.title

    #         # if list is longer than 50, remove last item
    #         limited_log_from = update_logs(log_from, town_from.logs)
    #         limited_log_to = update_logs(log_to, town_to.logs)

    #         town_from_changeset =
    #           town_from
    #           |> City.Town.changeset(%{logs: limited_log_from})

    #         town_to_changeset =
    #           town_to
    #           |> City.Town.changeset(%{logs: limited_log_to})

    #         Ecto.Multi.update(multi, {:update_citizen_town, citizen.id}, citizen_changeset)
    #         |> Ecto.Multi.update({:update_town_from, citizen.id}, town_from_changeset)
    #         |> Ecto.Multi.update({:update_town_to, citizen.id}, town_to_changeset)
    #       else
    #         multi
    #       end
    #     end)
    #     |> Repo.transaction(timeout: 240_000)
    #   end)
    # end

    updated_citizens_by_id_3 =
      Enum.reduce(preferred_locations.choices, updated_citizens_by_id_2, fn {citizen,
                                                                             chosen_city_id},
                                                                            acc ->
        if citizen.town_id != chosen_city_id do
          acc |> Map.update!(chosen_city_id, &[citizen | &1])
        else
          acc
        end
      end)

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 3: MOVE CITIZENS WITHOUT HOUSING ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    occupied_slots_2 =
      Enum.map(preferred_locations.choices, fn {_citizen_id, city_id} ->
        city_id
      end)

    slots_after_housing_migrations =
      if slots_after_job_migrations == %{} do
        %{}
      else
        Enum.reduce(occupied_slots_2, slots_after_job_migrations, fn city_id, acc ->
          # need to find the right key, these cities are already normalized
          if is_nil(city_id) do
            acc
          else
            # key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
            Map.update!(acc, city_id, &(&1 - 1))
            # TODO
            # this seems like something that could be done with ETS
          end
        end)
      end

    housing_slots_2_expanded =
      Enum.reduce(
        slots_after_housing_migrations,
        [],
        fn {city_id, slots_count}, acc ->
          # duplicate this score v times (1 for each slot)

          if slots_count > 0 do
            acc ++ for _ <- 1..slots_count, do: city_id
          else
            acc
          end
        end
      )

    unhoused_split = unhoused_citizens |> Enum.split(length(housing_slots_2_expanded))

    slots_filtered =
      Enum.filter(slots_after_housing_migrations, fn {_k, v} -> v > 0 end) |> Enum.into(%{})

    # SHAPE OF unhoused_locations.choices is an array of {citizen, city_id}
    unhoused_locations =
      Enum.reduce(elem(unhoused_split, 0), %{choices: [], slots: slots_filtered}, fn citizen,
                                                                                     acc ->
        chosen_city =
          Enum.reduce(acc.slots, %{chosen_id: 0, top_score: 0}, fn {city_id, count}, acc2 ->
            score =
              if count > 0 do
                Float.round(
                  citizen_score(
                    citizen.preferences,
                    citizen.education,
                    slotted_cities_by_id[city_id]
                  ),
                  4
                )
              else
                0
              end

            if score > acc2.top_score do
              %{
                chosen_id: city_id,
                top_score: score
              }
            else
              acc2
            end
          end)

        updated_slots =
          if chosen_city.chosen_id > 0 do
            if acc.slots[chosen_city.chosen_id] > 0 do
              Map.update!(acc.slots, chosen_city.chosen_id, &(&1 - 1))
            else
              Map.drop(acc.slots, [chosen_city.chosen_id])
            end
          else
            acc.slots
          end

        %{
          choices:
            if chosen_city.chosen_id == 0 do
              acc.choices
            else
              acc.choices ++ [{citizen, chosen_city.chosen_id}]
            end,
          slots: updated_slots
        }
      end)

    # if unhoused_locations.choices != [] do
    #   unhoused_locations.choices
    #   # |> Enum.sort_by(&elem(&1, 0).id)
    #   |> Enum.chunk_every(200)
    #   |> Enum.each(fn chunk ->
    #     Enum.reduce(chunk, Ecto.Multi.new(), fn {citizen, city_id}, multi ->
    #       # citizen = Enum.at(elem(unhoused_split, 0), citizen_index)
    #       town_from = struct(Town, slotted_cities_by_id[citizen.town_id].city)
    #       town_to = struct(Town, slotted_cities_by_id[city_id].city)

    #       if town_from.id != town_to.id do
    #         citizen_changeset =
    #           citizen
    #           |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

    #         log_from =
    #           CityHelpers.describe_citizen(citizen) <>
    #             " has moved to " <> town_to.title

    #         log_to =
    #           CityHelpers.describe_citizen(citizen) <>
    #             " has moved from " <> town_from.title

    #         # if list is longer than 50, remove last item
    #         limited_log_from = update_logs(log_from, town_from.logs)
    #         limited_log_to = update_logs(log_to, town_to.logs)

    #         town_from_changeset =
    #           town_from
    #           |> City.Town.changeset(%{logs: limited_log_from})

    #         town_to_changeset =
    #           town_to
    #           |> City.Town.changeset(%{logs: limited_log_to})

    #         Ecto.Multi.update(multi, {:update_citizen_town, citizen.id}, citizen_changeset)
    #         |> Ecto.Multi.update({:update_town_from, citizen.id}, town_from_changeset)
    #         |> Ecto.Multi.update({:update_town_to, citizen.id}, town_to_changeset)
    #       else
    #         multi
    #       end
    #     end)
    #     |> Repo.transaction(timeout: 220_000)
    #   end)
    # end

    updated_citizens_by_id_4 =
      Enum.reduce(unhoused_locations.choices, updated_citizens_by_id_3, fn {citizen,
                                                                            chosen_city_id},
                                                                           acc ->
        if citizen.town_id != chosen_city_id do
          acc |> Map.update!(chosen_city_id, &[citizen | &1])
        else
          acc
        end
      end)

    Repo.checkout(
      fn ->
        updated_citizens_by_id_4
        |> Enum.chunk_every(200)
        |> Enum.each(fn chunk ->
          Enum.each(chunk, fn {id, list} ->
            # town_ids = chunk |> Enum.map(fn {id, _list} -> id end) |> Enum.sort()

            # from(t in Town,
            #   where: t.id in ^town_ids,
            #   update: [set: [citizens_blob: ^chunk[t.id], citizen_count: ^length(chunk[t.id])]]
            # )
            # |> Repo.update_all([])

            from(t in Town,
              where: t.id == ^id,
              update: [
                set: [
                  citizen_count: ^length(list),
                  citizens_blob: ^list
                ]
              ]
            )
            |> Repo.update_all([])
          end)
        end)

        # MULTI KILL REST OF UNHOUSED CITIZENS

        # elem(unhoused_split, 1)
        # |> Enum.sort_by(& &1.id)
        # |> Enum.chunk_every(200)
        # |> Enum.each(fn chunk ->
        #   citizen_ids = chunk |> Enum.map(fn citizen -> citizen.id end) |> Enum.sort()

        #   town_ids = chunk |> Enum.map(fn citizen -> citizen.town_id end) |> Enum.sort()

        #   from(c in Citizens, where: c.id in ^citizen_ids)
        #   |> Repo.delete_all()

        #   from(t in Town,
        #     where: t.id in ^town_ids,
        #     update: [push: [logs: "A citizen died a lack of housing. RIP"]]
        #   )
        #   |> Repo.update_all([])
        # end)

        #

        # ——————————————————————————————————————————————————————————————————————————————————
        # ————————————————————————————————————————— OTHER ECTO UPDATES
        # ——————————————————————————————————————————————————————————————————————————————————

        # MULTI UPDATE: update city money/treasury in DB ——————————————————————————————————————————————————— DB UPDATE

        # IF I MAKE THIS ATOMIC, DON'T NEED TO DO THIS
        # delete_all

        # MULTI CHANGESET EDUCATE ——————————————————————————————————————————————————— DB UPDATE

        # test = [1, 4]

        # IO.inspect(cs)

        # if rem(world.day, 365) == 0 do

        # end

        # end)

        # MULTI CHANGESET AGE

        # MULTI CHANGESET KILL OLD CITIZENS ——————————————————————————————————————————————————— DB UPDATE

        # end)

        # MULTI REPRODUCE ——————————————————————————————————————————————————— DB UPDATE
      end,
      timeout: 6_000_000
    )

    # SEND RESULTS TO CLIENTS
    # send val to liveView process that manages front-end; this basically sends to every client.
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "pong",
      db_world
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 10000)

    # returns this to whatever calls ?
    {:noreply, %{world: db_world, buildables_map: buildables_map}}
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

  def nil_value_check(map, key) do
    if Map.has_key?(map, key), do: map[key], else: 0
  end

  def normalize_city(city, max_fun, spread_health, spread_pollution, max_sprawl) do
    %{
      city: city,
      jobs: city.jobs,
      id: city.id,
      sprawl_normalized: zero_check(nil_value_check(city, :sprawl), max_sprawl),
      pollution_normalized: zero_check(nil_value_check(city, :pollution), spread_pollution),
      fun_normalized: zero_check(nil_value_check(city, :fun), max_fun),
      health_normalized: zero_check(nil_value_check(city, :health), spread_health),
      tax_rates: city.tax_rates
    }
  end

  def zero_check(check, divisor) do
    if check == 0 or divisor == 0, do: 0, else: check / divisor
  end

  def citizen_score(citizen_preferences, education_level, normalized_city) do
    (1 - normalized_city.tax_rates[to_string(education_level)]) * citizen_preferences["tax_rates"] +
      (1 - normalized_city.pollution_normalized) * citizen_preferences["pollution"] +
      (1 - normalized_city.sprawl_normalized) * citizen_preferences["sprawl"] +
      normalized_city.fun_normalized * citizen_preferences["fun"] +
      normalized_city.health_normalized * citizen_preferences["health"]
  end
end
