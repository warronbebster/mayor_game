defmodule MayorGame.CityCalculator do
  use GenServer, restart: :permanent
  alias MayorGame.{City, CityHelpersTwo, Repo}
  # alias MayorGame.City.Details

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
    IO.puts('init')
    # initial_val is 1 here, set in application.ex then started with start_link

    game_world = City.get_world!(initial_world)
    IO.inspect(game_world)

    # send message :tax to self process after 5000ms
    # calls `handle_info` function
    Process.send_after(self(), :tax, 5000)

    # returns ok tuple when u start
    {:ok, game_world}
  end

  # when :tax is sent
  def handle_info(:tax, world) do
    cities = City.list_cities_preload()
    cities_count = Enum.count(cities)

    pollution_ceiling =
      cities_count * 10000_000 +
        10000_000 * Random.gammavariate(7.5, 1)

    db_world = City.get_world!(1)

    IO.puts(
      "day: " <>
        to_string(db_world.day) <>
        " | cities: " <>
        to_string(cities_count) <>
        " | pollution: " <>
        to_string(db_world.pollution) <> " | —————————————————————————————————————————————"
    )

    cities_list = if rem(db_world.day, 2) == 1, do: Enum.reverse(cities), else: cities

    # result is map %{cities_w_room: [], citizens_looking: [], citizens_to_reproduce: [], etc}
    # FIRST ROUND CHECK
    # go through all cities
    # could try flowing this
    leftovers =
      Enum.reduce(
        cities_list,
        %{
          # all_cities: [],
          all_cities_new: [],
          citizens_looking: [],
          citizens_out_of_room: [],
          citizens_learning: %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => []},
          citizens_too_old: [],
          citizens_polluted: [],
          citizens_to_reproduce: [],
          new_world_pollution: 0,
          housed_unemployed_citizens: [],
          housed_employed_looking_citizens: [],
          unhoused_citizens: [],
          housing_slots: %{},
          sprawl_max: 0,
          fun_max: 0,
          pollution_max: 0,
          health_max: 0
        },
        fn city, acc ->
          # result here is a %Town{} with stats calculated
          # city_with_stats = MayorGame.CityHelpers.calculate_city_stats(city, db_world)

          city_with_stats2 =
            CityHelpersTwo.calculate_city_stats(
              city,
              db_world,
              cities_count,
              pollution_ceiling
            )

          citizens_looking =
            city_with_stats2.housed_unemployed_citizens ++
              city_with_stats2.housed_employed_looking_citizens

          housing_slots = city_with_stats2.housing_left

          # + length(city_with_stats2.housed_unemployed_citizens) + length(city_with_stats2.housed_employed_looking_citizens)

          %{
            all_cities_new: [city_with_stats2 | acc.all_cities_new],
            # all_cities: [city_calculated_values | acc.all_cities],
            citizens_too_old: city_with_stats2.old_citizens ++ acc.citizens_too_old,
            citizens_learning:
              Map.merge(city_with_stats2.educated_citizens, acc.citizens_learning, fn _k,
                                                                                      v1,
                                                                                      v2 ->
                v1 ++ v2
              end),
            citizens_polluted: city_with_stats2.polluted_citizens ++ acc.citizens_polluted,
            citizens_to_reproduce:
              city_with_stats2.reproducing_citizens ++ acc.citizens_to_reproduce,
            citizens_out_of_room: city_with_stats2.unhoused_citizens ++ acc.citizens_out_of_room,
            citizens_looking: citizens_looking ++ acc.citizens_looking,
            new_world_pollution: city_with_stats2.pollution + acc.new_world_pollution,
            housed_unemployed_citizens:
              city_with_stats2.housed_unemployed_citizens ++ acc.housed_unemployed_citizens,
            housed_employed_looking_citizens:
              city_with_stats2.housed_employed_looking_citizens ++
                acc.housed_employed_looking_citizens,
            unhoused_citizens: city_with_stats2.unhoused_citizens ++ acc.unhoused_citizens,
            housing_slots:
              if(housing_slots > 0,
                do: Map.put(acc.housing_slots, city_with_stats2, housing_slots),
                else: acc.housing_slots
              ),
            sprawl_max:
              if(Map.has_key?(city_with_stats2, :sprawl),
                do: max(city_with_stats2.sprawl, acc.sprawl_max),
                else: acc.sprawl_max
              ),
            fun_max:
              if(Map.has_key?(city_with_stats2, :fun),
                do: max(city_with_stats2.fun, acc.fun_max),
                else: acc.fun_max
              ),
            pollution_max:
              if(Map.has_key?(city_with_stats2, :pollution),
                do: max(city_with_stats2.pollution, acc.pollution_max),
                else: acc.pollution_max
              ),
            health_max:
              if(Map.has_key?(city_with_stats2, :health),
                do: max(city_with_stats2.health, acc.health_max),
                else: acc.health_max
              )
          }
        end
      )

    total_slots =
      leftovers.housing_slots
      |> Map.values()
      |> Enum.sum()

    IO.inspect(total_slots, label: "housing_left")

    # ok so here each city has

    IO.inspect("starting round 1")

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
    # or the map is just of the ones with housing slots (e.g. in leftovers.housing_slots)
    slotted_cities_by_id =
      Map.keys(leftovers.housing_slots)
      |> Enum.map(fn city ->
        normalize_city(
          city,
          leftovers.fun_max,
          leftovers.health_max,
          leftovers.pollution_max,
          leftovers.sprawl_max
        )
      end)
      |> Map.new(fn city -> {city.id, city} end)

    # shape: %{
    # city_id: {normalized_city, slots},
    # city_id: {normalized_city, slots}
    # }

    # shape: %{
    # city_id: slots
    # }
    housing_slots_by_city_id =
      leftovers.housing_slots
      |> Enum.map(fn {city, slots} ->
        {city.id, slots}
      end)
      |> Enum.into(%{})

    # leftovers.housing_slots is a list of {city, number of slots}
    job_and_housing_slots_normalized =
      Enum.reduce(
        housing_slots_by_city_id,
        %{level_slots: level_slots, total_slots_left: total_slots},
        fn {normalized_city_id, housing_slots_count}, acc ->
          slots_per_level =
            Enum.reduce(
              slotted_cities_by_id[normalized_city_id].city.jobs,
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

          # IO.inspect(slots_per_level)

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

    IO.inspect('after job slots per level calculated')

    citizens_split =
      Map.new(0..5, fn x ->
        {x,
         Enum.split(
           Enum.filter(leftovers.citizens_looking, fn cit -> cit.education == x end),
           job_and_housing_slots_normalized.level_slots[x].total_slots
         )}
      end)

    # split looking
    IO.inspect("Citizen splits done")

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
               if acc.slots != %{} do
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

    # preference_maps_by_level =
    #   Map.new(0..5, fn level ->
    #     IO.inspect(job_and_housing_slots_normalized.level_slots[level].total_slots,
    #       label: "job & housing slots for level " <> to_string(level)
    #     )

    #     {level,
    #      Enum.map(
    #        elem(citizens_split[level], 0),
    #        fn citizen ->
    #          Enum.reduce(
    #            job_and_housing_slots_normalized.level_slots[level].normalized_cities,
    #            [],
    #            fn {city_id, slots_count}, acc ->
    #              # duplicate this score v times (1 for each slot)

    #              # check if v is 0 here
    #              score =
    #                Float.round(
    #                  citizen_score(
    #                    citizen.preferences,
    #                    citizen.education,
    #                    slotted_cities_by_id[city_id]
    #                  ),
    #                  4
    #                )

    #              if slots_count > 0 do
    #                acc ++ for _ <- 1..slots_count, do: score
    #              else
    #                acc
    #              end
    #            end
    #          )
    #        end
    #      )}
    #   end)

    IO.inspect("preference maps generated")

    looking_but_not_in_job_race =
      Enum.reduce(citizens_split, [], fn {_k, v}, acc ->
        acc ++ elem(v, 1)
      end)

    # array of citizens who are still looking, that didn't make it into the level-specific comparisons

    # if not empty
    # run hungarian
    #
    IO.inspect("about to compute results")

    # hungarian_results_by_level =
    #   Map.new(0..5, fn x ->
    #     IO.inspect(length(preference_maps_by_level[x]),
    #       label: "preference map length for level " <> to_string(x)
    #     )

    #     {x,
    #      if(preference_maps_by_level[x] != [],
    #        do: compute_destination(preference_maps_by_level[x]),
    #        else: %{matrix: [], output: []}
    #      )}
    #   end)

    IO.inspect("round 1 computation done")

    # MULTI CHANGESET MOVE JOB SEARCHING CITIZENS
    # MOVE CITIZENS
    Enum.map(0..5, fn x ->
      if preferred_locations_by_level[x].choices != [] do
        preferred_locations_by_level[x].choices
        |> Enum.chunk_every(100)
        |> Flow.from_enumerable(max_demand: 20)
        |> Flow.map(fn chunk ->
          Enum.reduce(chunk, Ecto.Multi.new(), fn {citizen, city_id}, multi ->
            # citizen = Enum.at(elem(citizens_split[x], 0), citizen_index)
            town_from = City.get_town!(citizen.town_id)

            town_to = city_id

            if town_from.id != town_to.id do
              citizen_changeset =
                citizen
                |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

              log_from =
                CityHelpersTwo.describe_citizen(citizen) <>
                  " has moved to " <> town_to.title

              log_to =
                CityHelpersTwo.describe_citizen(citizen) <>
                  " has moved from " <> town_from.title

              # if list is longer than 50, remove last item
              limited_log_from = update_logs(log_from, town_from.logs)
              limited_log_to = update_logs(log_to, town_to.logs)

              town_from_changeset =
                town_from
                |> City.Town.changeset(%{logs: limited_log_from})

              town_to_changeset =
                town_to
                |> City.Town.changeset(%{logs: limited_log_to})

              Ecto.Multi.update(multi, {:update_citizen_town, citizen.id}, citizen_changeset)
              |> Ecto.Multi.update({:update_town_from, citizen.id}, town_from_changeset)
              |> Ecto.Multi.update({:update_town_to, citizen.id}, town_to_changeset)
            else
              multi
            end
          end)
          |> Repo.transaction()
        end)
      end
    end)

    IO.inspect("round 1 database updates done")

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 2: MOVE CITIZENS ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    # this produces a list of cities that have been occupied
    occupied_slots =
      Enum.flat_map(preferred_locations_by_level, fn {level, preferred_locations} ->
        Enum.map(preferred_locations.choices, fn {_citizen_id, city_id} ->
          city_id

          # could also potentially move the citizens here
          # could move citizens here
          # COULD MOVE CITIZENS HERE ———————————————————————————————————
        end)
      end)

    IO.inspect(occupied_slots, label: "occupied_slots")

    # take housing slots, remove any city that was occupied previously
    slots_after_job_migrations =
      if leftovers.housing_slots == %{} do
        %{}
      else
        Enum.reduce(occupied_slots, housing_slots_by_city_id, fn city_id, acc ->
          # need to find the right key, these cities are already normalized
          if is_nil(city_id) do
            acc
          else
            # key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
            Map.update!(acc, city_id, &(&1 - 1))
          end
        end)
      end

    IO.inspect(slots_after_job_migrations)

    # housing_slots_normalized =
    #   Enum.map(slots_after_job_migrations, fn {k, v} ->
    #     {normalize_city(
    #        k,
    #        leftovers.fun_max,
    #        leftovers.health_max,
    #        leftovers.pollution_max,
    #        leftovers.sprawl_max
    #      ), v}
    #   end)

    housing_slots_expanded =
      Enum.reduce(
        slots_after_job_migrations,
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

    # Enum.flat_map(slots_after_job_migrations, fn {k, v} ->
    #   # duplicate this score v times (1 for each slot)

    #   for _ <- 1..v,
    #       do: k
    # end)

    # ok

    slots_after_job_filtered =
      Enum.filter(slots_after_job_migrations, fn {_k, v} -> v > 0 end) |> Enum.into(%{})

    IO.inspect(length(housing_slots_expanded), label: 'housing slots')
    IO.inspect(length('looking_but_not_in_job_race'), label: 'citizens looking')

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
            if acc.slots != %{} do
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

    IO.inspect(Enum.member?(Keyword.values(preferred_locations.choices), 0), label: "HAS ID ZERO")

    # preference_maps =
    #   Enum.map(looking_but_not_in_job_race, fn citizen ->
    #     # for each slot
    #     Enum.reduce(
    #       slots_after_job_migrations,
    #       [],
    #       fn {city_id, slots_count}, acc ->
    #         # duplicate this score v times (1 for each slot)

    #         score =
    #           Float.round(
    #             citizen_score(
    #               citizen.preferences,
    #               citizen.education,
    #               slotted_cities_by_id[city_id]
    #             ),
    #             4
    #           )

    #         if slots_count > 0 do
    #           acc ++ for _ <- 1..slots_count, do: score
    #         else
    #           acc
    #         end
    #       end
    #     )
    #   end)

    IO.inspect(length(looking_but_not_in_job_race), label: 'citizens looking')
    # IO.inspect(length(preference_maps), label: 'preference_maps length')
    # IO.inspect(preference_maps, label: 'preference_maps')

    # hungarian_results =
    #   if preference_maps != [],
    #     do: compute_destination(preference_maps),
    #     else: %{matrix: [], output: []}

    # pass in list of lists
    # firs tlist index is citizen index
    # second tier is cities
    # [
    #   [.5, .6, .7]
    # ]

    # returns list of [{citizen_index, city_index}]

    # MULTI CHANGESET MOVE LOOKING CITIZENS
    # MOVE CITIZENS

    IO.inspect("round 2 computation done")

    if preferred_locations.choices != [] do
      preferred_locations.choices
      |> Enum.chunk_every(100)
      |> Flow.from_enumerable(max_demand: 20)
      |> Flow.map(fn chunk ->
        Enum.reduce(chunk, Ecto.Multi.new(), fn {citizen, city_id}, multi ->
          # citizen = Enum.at(looking_but_not_in_job_race, citizen_index)
          town_from = City.get_town!(citizen.town_id)
          town_to = City.get_town!(city_id)

          if town_from.id != town_to.id do
            citizen_changeset =
              citizen
              |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

            log_from =
              CityHelpersTwo.describe_citizen(citizen) <>
                " has moved to " <> town_to.title

            log_to =
              CityHelpersTwo.describe_citizen(citizen) <>
                " has moved from " <> town_from.title

            # if list is longer than 50, remove last item
            limited_log_from = update_logs(log_from, town_from.logs)
            limited_log_to = update_logs(log_to, town_to.logs)

            town_from_changeset =
              town_from
              |> City.Town.changeset(%{logs: limited_log_from})

            town_to_changeset =
              town_to
              |> City.Town.changeset(%{logs: limited_log_to})

            Ecto.Multi.update(multi, {:update_citizen_town, citizen.id}, citizen_changeset)
            |> Ecto.Multi.update({:update_town_from, citizen.id}, town_from_changeset)
            |> Ecto.Multi.update({:update_town_to, citizen.id}, town_to_changeset)
          else
            multi
          end
        end)
        |> Repo.transaction()
      end)
    end

    IO.inspect("round 2 database updates done")

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 3: MOVE CITIZENS WITHOUT HOUSING ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    # occupied_slots_2 =
    #   Enum.map(hungarian_results.output, fn {_citizen_id, city_id} ->
    #     Enum.at(housing_slots_expanded, city_id)
    #   end)

    # IO.inspect(length(occupied_slots_2))

    occupied_slots_2 =
      Enum.map(preferred_locations.choices, fn {_citizen_id, city_id} ->
        city_id
      end)

    # IO.inspect(length(occupied_slots_3))

    # IO.inspect(Enum.sort(occupied_slots_2) == Enum.sort(occupied_slots_3))

    # slots_after_housing_migrations =
    #   if slots_after_job_migrations == %{} do
    #     %{}
    #   else
    #     Enum.reduce(occupied_slots_2, slots_after_job_migrations, fn city, acc ->
    #       # need to find the right key, these cities are already normalized
    #       key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
    #       Map.update!(acc, key, &(&1 - 1))
    #     end)
    #   end

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
          end
        end)
      end

    # housing_slots_3_normalized =
    #   Enum.map(slots_after_housing_migrations, fn {k, v} ->
    #     {normalize_city(
    #        k,
    #        leftovers.fun_max,
    #        leftovers.health_max,
    #        leftovers.pollution_max,
    #        leftovers.sprawl_max
    #      ), v}
    #   end)

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

    unhoused_split =
      Enum.shuffle(leftovers.unhoused_citizens) |> Enum.split(length(housing_slots_2_expanded))

    # unhoused_preference_maps =
    #   Enum.map(elem(unhoused_split, 0), fn citizen ->
    #     Enum.flat_map(housing_slots_2_expanded, fn {k, v} ->
    #       # duplicate this score v times (1 for each slot)

    #       score = Float.round(1 - citizen_score(citizen.preferences, citizen.education, k), 4)

    #       for _ <- 1..v,
    #           do: score
    #     end)
    #   end)

    # could reduce for each citizen
    # acc is slots (e.g. housing_slots_2_expanded)
    # calc score per city
    # get max
    # id is good
    # filter slots_after_housing_migrations by
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
          if acc.slots[chosen_city.chosen_id] > 0 do
            Map.update!(acc.slots, chosen_city.chosen_id, &(&1 - 1))
          else
            Map.drop(acc.slots, [chosen_city.chosen_id])
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

    # unhoused_preference_maps =
    #   Enum.map(elem(unhoused_split, 0), fn citizen ->
    #     # for each slot
    #     Enum.reduce(
    #       housing_slots_2_expanded,
    #       [],
    #       fn {city_id, slots_count}, acc ->
    #         # duplicate this score v times (1 for each slot)

    #         score =
    #           Float.round(
    #             citizen_score(
    #               citizen.preferences,
    #               citizen.education,
    #               slotted_cities_by_id[city_id]
    #             ),
    #             4
    #           )

    #         if slots_count > 0 do
    #           acc ++ for _ <- 1..slots_count, do: score
    #         else
    #           acc
    #         end
    #       end
    #     )
    #   end)

    # hungarian_results_unhoused =
    #   if unhoused_preference_maps != [],
    #     do: compute_destination(unhoused_preference_maps),
    #     else: %{matrix: [], output: []}

    IO.inspect("round 3 computation done")

    if unhoused_locations.choices != [] do
      unhoused_locations.choices
      |> Enum.chunk_every(100)
      |> Flow.from_enumerable(max_demand: 20)
      |> Flow.map(fn chunk ->
        Enum.reduce(chunk, Ecto.Multi.new(), fn {citizen, city_id}, multi ->
          # citizen = Enum.at(elem(unhoused_split, 0), citizen_index)
          town_from = City.get_town!(citizen.town_id)
          town_to = City.get_town!(city_id)

          if town_from.id != town_to.id do
            citizen_changeset =
              citizen
              |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

            log_from =
              CityHelpersTwo.describe_citizen(citizen) <>
                " has moved to " <> town_to.title

            log_to =
              CityHelpersTwo.describe_citizen(citizen) <>
                " has moved from " <> town_from.title

            # if list is longer than 50, remove last item
            limited_log_from = update_logs(log_from, town_from.logs)
            limited_log_to = update_logs(log_to, town_to.logs)

            town_from_changeset =
              town_from
              |> City.Town.changeset(%{logs: limited_log_from})

            town_to_changeset =
              town_to
              |> City.Town.changeset(%{logs: limited_log_to})

            Ecto.Multi.update(multi, {:update_citizen_town, citizen.id}, citizen_changeset)
            |> Ecto.Multi.update({:update_town_from, citizen.id}, town_from_changeset)
            |> Ecto.Multi.update({:update_town_to, citizen.id}, town_to_changeset)
          else
            multi
          end
        end)
        |> Repo.transaction()
      end)
    end

    # MULTI KILL REST OF UNHOUSED CITIZENS
    elem(unhoused_split, 1)
    |> Enum.chunk_every(100)
    |> Flow.from_enumerable(max_demand: 20)
    |> Flow.map(fn chunk ->
      Enum.with_index(chunk)
      |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
        town = City.get_town!(citizen.town_id)

        log =
          CityHelpersTwo.describe_citizen(citizen) <>
            " has died because of a lack of housing. RIP"

        limited_log = update_logs(log, town.logs)

        town_changeset =
          town
          |> City.Town.changeset(%{logs: limited_log})

        Ecto.Multi.delete(multi, {:delete, idx}, citizen)
        |> Ecto.Multi.update({:update, idx}, town_changeset)
      end)
      |> Repo.transaction()
    end)

    #

    # unhoused_citizens (no anything)

    IO.inspect("round 3 database updates done")

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— OTHER ECTO UPDATES
    # ——————————————————————————————————————————————————————————————————————————————————

    # MULTI UPDATE: update city money/treasury in DB
    leftovers.all_cities_new
    |> Enum.chunk_every(100)
    |> Flow.from_enumerable(max_demand: 20)
    |> Flow.map(fn chunk ->
      Enum.with_index(chunk)
      |> Enum.reduce(Ecto.Multi.new(), fn {city, idx}, multi ->
        updated_city_treasury =
          if city.money < 0,
            do: 0,
            else: city.money

        details_update_changeset =
          city.details
          |> City.Details.changeset(%{
            city_treasury: updated_city_treasury,
            pollution: city.pollution
          })

        Ecto.Multi.update(multi, {:update_towns, idx}, details_update_changeset)
      end)
      |> Repo.transaction()
    end)

    # MULTI CHANGESET EDUCATE

    leftovers.citizens_learning
    |> Enum.chunk_every(100)
    |> Flow.from_enumerable(max_demand: 20)
    |> Flow.map(fn chunk ->
      Enum.map(chunk, fn {level, list} ->
        list
        |> Enum.with_index()
        |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
          town = City.get_town!(citizen.town_id)

          log =
            CityHelpersTwo.describe_citizen(citizen) <>
              " has graduated to level " <> to_string(level)

          # if list is longer than 50, remove last item
          limited_log = update_logs(log, town.logs)

          citizen_changeset =
            citizen
            |> City.Citizens.changeset(%{education: level})

          town_changeset =
            town
            |> City.Town.changeset(%{logs: limited_log})

          Ecto.Multi.update(multi, {:update_citizen_edu, idx}, citizen_changeset)
          |> Ecto.Multi.update({:update_town_log, idx}, town_changeset)
        end)
        |> Repo.transaction()
      end)
    end)

    # MULTI CHANGESET AGE

    Repo.update_all(MayorGame.City.Citizens, inc: [age: 1])

    # MULTI CHANGESET KILL OLD CITIZENS
    leftovers.citizens_too_old
    |> Enum.chunk_every(100)
    |> Flow.from_enumerable(max_demand: 20)
    |> Flow.map(fn chunk ->
      Enum.with_index(chunk)
      |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
        town = City.get_town!(citizen.town_id)

        log = CityHelpersTwo.describe_citizen(citizen) <> " has died because of old age. RIP"

        # if list is longer than 50, remove last item
        limited_log = update_logs(log, town.logs)

        town_changeset =
          town
          |> City.Town.changeset(%{logs: limited_log})

        Ecto.Multi.delete(multi, {:delete, idx}, citizen)
        |> Ecto.Multi.update({:update, idx}, town_changeset)
      end)
      |> Repo.transaction()
    end)

    # MULTI KILL POLLUTED CITIZENS
    leftovers.citizens_polluted
    |> Enum.chunk_every(100)
    |> Flow.from_enumerable(max_demand: 20)
    |> Flow.map(fn chunk ->
      Enum.with_index(chunk)
      |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
        town = City.get_town!(citizen.town_id)

        log =
          CityHelpersTwo.describe_citizen(citizen) <>
            " has died because of pollution. RIP"

        limited_log = update_logs(log, town.logs)

        town_changeset =
          town
          |> City.Town.changeset(%{logs: limited_log})

        Ecto.Multi.delete(multi, {:delete, idx}, citizen)
        |> Ecto.Multi.update({:update, idx}, town_changeset)
      end)
      |> Repo.transaction()
    end)

    # MULTI REPRODUCE
    leftovers.citizens_to_reproduce
    |> Enum.chunk_every(100)
    |> Flow.from_enumerable(max_demand: 20)
    |> Flow.map(fn chunk ->
      Enum.with_index(chunk)
      |> Enum.reduce(Ecto.Multi.new(), fn {citizen, idx}, multi ->
        town = City.get_town!(citizen.town_id)

        log =
          CityHelpersTwo.describe_citizen(citizen) <>
            " had a child"

        limited_log = update_logs(log, town.logs)
        # if list is longer than 50, remove last item

        changeset =
          City.create_citizens_changeset(%{
            money: 0,
            town_id: citizen.town_id,
            age: 0,
            education: 0,
            has_car: false,
            has_job: false,
            last_moved: db_world.day
          })

        town_changeset =
          town
          |> City.Town.changeset(%{logs: limited_log})

        Ecto.Multi.insert(multi, {:add_citizen, idx}, changeset)
        |> Ecto.Multi.update({:update, idx}, town_changeset)
      end)
      |> Repo.transaction()
    end)

    updated_pollution =
      if db_world.pollution + leftovers.new_world_pollution < 0 do
        0
      else
        db_world.pollution + leftovers.new_world_pollution
      end

    # update World in DB, pull updated_world var out of response
    {:ok, updated_world} =
      City.update_world(db_world, %{
        day: db_world.day + 1,
        pollution: updated_pollution
      })

    # SEND RESULTS TO CLIENTS
    # send val to liveView process that manages front-end; this basically sends to every client.

    IO.inspect("broadcast again")

    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "ping",
      updated_world
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 5000)

    # returns this to whatever calls ?
    {:noreply, updated_world}
  end

  def update_logs(log, existing_logs) do
    updated_log = [log | existing_logs]

    if length(updated_log) > 50 do
      updated_log |> Enum.reverse() |> tl() |> Enum.reverse()
    else
      updated_log
    end
  end

  def nil_value_check(map, key) do
    if Map.has_key?(map, key), do: map[key], else: 0
  end

  def normalize_city(city, max_fun, max_health, max_pollution, max_sprawl) do
    %{
      city: city,
      id: city.id,
      sprawl_normalized: zero_check(nil_value_check(city, :sprawl), max_sprawl),
      pollution_normalized: zero_check(nil_value_check(city, :pollution), max_pollution),
      fun_normalized: zero_check(nil_value_check(city, :fun), max_fun),
      health_normalized: zero_check(nil_value_check(city, :health), max_health),
      tax_rates: city.tax_rates
    }
  end

  def zero_check(check, divisor) do
    if check == 0 or divisor == 0, do: 0, else: check / divisor
  end

  def citizen_score(citizen_preferences, education_level, normalized_city) do
    normalized_city.tax_rates[to_string(education_level)] * citizen_preferences["tax_rates"] +
      normalized_city.pollution_normalized * citizen_preferences["pollution"] +
      normalized_city.sprawl_normalized * citizen_preferences["sprawl"] +
      normalized_city.fun_normalized * citizen_preferences["fun"] +
      normalized_city.health_normalized * citizen_preferences["health"]
  end

  def compute_destination([row1 | _] = matrix) do
    Enum.reduce(0..(length(matrix) - 1), %{matrix: matrix, output: []}, fn row_index, acc ->
      # find best one
      row = Enum.at(acc.matrix, row_index)

      max = Enum.max(row)
      chosen_index = Enum.find_index(row, fn x -> x == max end)
      # chosen_index = Enum.find(row, fn x -> x == max end)

      updated_matrix =
        Enum.map(acc.matrix, fn row ->
          List.replace_at(row, chosen_index, -1)
        end)

      %{
        matrix: updated_matrix,
        output: [{row_index, chosen_index} | acc.output]
      }
    end)

    # end with list [{index, best option}]
  end
end
