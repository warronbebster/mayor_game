defmodule MayorGame.CityMigrator do
  use GenServer, restart: :permanent
  alias MayorGame.City.{Town, Citizens, Buildable}
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
    Process.send_after(self(), :tax, 5000)

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
        rem(db_world.day, 365) < 91 -> :winter
        rem(db_world.day, 365) < 182 -> :spring
        rem(db_world.day, 365) < 273 -> :summer
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

    # maybe do this one step at a time
    # employed should only jump if there's something better
    citizens_looking =
      List.flatten(
        Enum.map(leftovers, fn city ->
          city.unemployed_citizens ++ city.employed_looking_citizens
        end)
      )

    employed_looking_citizens =
      List.flatten(Enum.map(leftovers, fn city -> city.employed_looking_citizens end))

    unemployed_citizens =
      List.flatten(Enum.map(leftovers, fn city -> city.unemployed_citizens end))

    unhoused_citizens = List.flatten(Enum.map(leftovers, fn city -> city.unhoused_citizens end))
    # new_world_pollution = Enum.sum(Enum.map(leftovers, fn city -> city.pollution end))
    total_housing_slots = Enum.sum(Enum.map(leftovers, fn city -> city.housing_left end))

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
        {city.id, city}
      end)

    updated_citizens_by_id =
      leftovers
      |> Map.new(fn city -> {city.id, city.housed_employed_staying_citizens} end)

    # IO.inspect(updated_citizens_by_id, label: "updated_citizens_by_id")

    # for each city
    # add an aempty list
    # first put staying citizens
    # then push other citizens into it
    # unemployed_citizens: [],
    # housed_employed_staying_citizens: [],
    # employed_looking_citizens: [],
    # unhoused_citizens: [],

    # :eprof.stop_profiling()
    # :eprof.analyze()

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 1: MOVE CITIZENS PER JOB LEVEL
    # ——————————————————————————————————————————————————————————————————————————————————

    level_slots =
      Map.new(0..5, fn x ->
        {x,
         %{normalized_cities: %{}, job_and_housing_slots: 0, job_and_housing_slots_expanded: []}}
      end)

    # sets up empty map for below function
    # SHAPE OF BELOW:
    # %{
    #   1: %{normalized_cities: [
    #     {city_normalized, # of slots}, {city_normalized, # of slots}
    #   ],
    #     total_slots: int,
    #     job_and_housing_slots_expanded: list of slots
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
        level_slots,
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
          # slots_taken_w_job = Enum.sum(Keyword.values(Map.values(slots_per_level)))

          # for each level in slots_per_level
          #
          level_results =
            Enum.map(5..0, fn x ->
              {x,
               %{
                 normalized_cities:
                   Map.put(
                     acc[x].normalized_cities,
                     elem(slots_per_level[x], 0),
                     elem(slots_per_level[x], 1)
                   ),

                 #  acc[x].normalized_cities ++ [slots_per_level[x]],
                 job_and_housing_slots:
                   acc[x].job_and_housing_slots + elem(slots_per_level[x], 1),
                 job_and_housing_slots_expanded:
                   if elem(slots_per_level[x], 1) > 0 do
                     acc[x].job_and_housing_slots_expanded ++
                       Enum.map(1..elem(slots_per_level[x], 1), fn _ -> normalized_city_id end)
                   else
                     acc[x].job_and_housing_slots_expanded
                   end
               }}
            end)
            |> Enum.into(%{})

          level_results
        end
      )

    # IO.inspect(job_and_housing_slots_normalized)

    # split by who will get to take the good slots
    # shape is map with key level, tuple
    # %{
    #   0 => {[citizens_searching], [citizens_not]},
    #   1 => {[citizens_searching], [citizens_not]},
    # }
    employed_citizens_split =
      Map.new(5..0, fn x ->
        {x,
         Enum.split(
           Enum.filter(employed_looking_citizens, fn cit -> cit.education == x end),
           job_and_housing_slots_normalized[x].job_and_housing_slots
         )}
      end)

    preferred_locations_by_level =
      Map.new(5..0, fn level ->
        {level,
         Enum.reduce(
           elem(employed_citizens_split[level], 0),
           %{
             choices: [],
             slots: job_and_housing_slots_normalized[level].normalized_cities
           },
           fn citizen, acc ->
             chosen_city =
               Enum.reduce(acc.slots, %{chosen_id: citizen.town_id, top_score: -1}, fn {city_id,
                                                                                        count},
                                                                                       acc2 ->
                 score =
                   if count > 0 do
                     Float.round(
                       citizen_score(
                         Citizens.preset_preferences()[citizen.preferences],
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
               if acc.slots != %{} && chosen_city.chosen_id != citizen.town_id do
                 acc.slots
                 |> Map.update!(chosen_city.chosen_id, &(&1 - 1))
                 |> Map.update(citizen.town_id, 0, &(&1 + 1))
               else
                 acc.slots
               end

             %{
               choices: acc.choices ++ [{citizen, chosen_city.chosen_id}],
               slots: updated_slots
             }
           end
         )}
      end)

    # find a way to return these to origin city
    looking_but_not_in_job_race =
      Enum.reduce(employed_citizens_split, [], fn {_k, v}, acc ->
        acc ++ elem(v, 1)
      end)

    # ^ array of citizens who are still looking, that didn't make it into the level-specific comparisons

    # update the citizen's choice
    updated_citizens_by_id_2 =
      Enum.reduce(5..0, updated_citizens_by_id, fn x, acc ->
        if preferred_locations_by_level[x].choices != [] do
          Enum.reduce(preferred_locations_by_level[x].choices, acc, fn {citizen, chosen_city_id},
                                                                       acc2 ->
            if citizen.town_id != chosen_city_id do
              acc2
              |> Map.update!(
                chosen_city_id,
                &[
                  citizen |> Map.drop([:town_id, :has_job]) |> Map.put(:last_moved, db_world.day)
                  | &1
                ]
              )
            else
              acc2
            end
          end)
        else
          acc
        end
      end)

    # add non-lookers back
    updated_citizens_by_id_3 =
      if looking_but_not_in_job_race != [] do
        Enum.reduce(looking_but_not_in_job_race, updated_citizens_by_id_2, fn citizen, acc ->
          acc
          |> Map.update!(
            citizen.town_id,
            &[
              citizen |> Map.drop([:town_id, :has_job]) |> Map.put(:last_moved, db_world.day) | &1
            ]
          )
        end)
      else
        updated_citizens_by_id_2
      end

    # IO.inspect(preferred_locations_by_level[0].slots)
    # ^ I think these should work as a substitute for job_and_housing_slots_normalized[x].job_and_housing_slots
    # ok these are…

    vacated_slots =
      Enum.flat_map(preferred_locations_by_level, fn {_level, preferred_locations} ->
        preferred_locations.choices
        |> Enum.filter(fn {citizen, city_id} -> citizen.town_id != city_id end)
        |> Enum.map(fn {citizen, _city_id} -> citizen.town_id end)
      end)

    occupied_slots =
      Enum.flat_map(preferred_locations_by_level, fn {_level, preferred_locations} ->
        preferred_locations.choices
        |> Enum.filter(fn {citizen, city_id} -> citizen.town_id != city_id end)
        |> Enum.map(fn {_citizen, city_id} -> city_id end)
      end)

    vacated_freq = Enum.frequencies(vacated_slots)
    occupied_freq = Enum.frequencies(occupied_slots)

    housing_slots_2 =
      housing_slots
      |> Map.merge(vacated_freq, fn _k, v1, v2 -> v1 - v2 end)
      |> Map.merge(occupied_freq, fn _k, v1, v2 -> v1 + v2 end)

    # NEW UNEMPLOYED CODE ————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————

    unemployed_citizens_split =
      Map.new(5..0, fn x ->
        {x,
         Enum.split(
           Enum.filter(unemployed_citizens, fn cit -> cit.education == x end),
           Enum.sum(Map.values(preferred_locations_by_level[x].slots))
         )}
      end)

    unemployed_preferred_locations_by_level =
      Map.new(5..0, fn level ->
        {level,
         Enum.reduce(
           elem(unemployed_citizens_split[level], 0),
           %{
             choices: [],
             slots: preferred_locations_by_level[level].slots
           },
           fn citizen, acc ->
             chosen_city =
               Enum.reduce(acc.slots, %{chosen_id: citizen.town_id, top_score: -1}, fn {city_id,
                                                                                        count},
                                                                                       acc2 ->
                 score =
                   if count > 0 do
                     Float.round(
                       citizen_score(
                         Citizens.preset_preferences()[citizen.preferences],
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
               if acc.slots != %{} && chosen_city.chosen_id != citizen.town_id do
                 acc.slots
                 |> Map.update!(chosen_city.chosen_id, &(&1 - 1))
                 |> Map.update(citizen.town_id, 0, &(&1 + 1))
               else
                 acc.slots
               end

             %{
               choices: acc.choices ++ [{citizen, chosen_city.chosen_id}],
               slots: updated_slots
             }
           end
         )}
      end)

    # find a way to return these to origin city
    unemployed_split_2 =
      Enum.reduce(unemployed_citizens_split, [], fn {_k, v}, acc ->
        acc ++ elem(v, 1)
      end)

    # ^ array of citizens who are still looking, that didn't make it into the level-specific comparisons

    # update the citizen's choice
    updated_citizens_by_id_4 =
      Enum.reduce(5..0, updated_citizens_by_id_3, fn x, acc ->
        if unemployed_preferred_locations_by_level[x].choices != [] do
          Enum.reduce(unemployed_preferred_locations_by_level[x].choices, acc, fn {citizen,
                                                                                   chosen_city_id},
                                                                                  acc2 ->
            if citizen.town_id != chosen_city_id do
              acc2
              |> Map.update!(
                chosen_city_id,
                &[
                  citizen |> Map.drop([:town_id, :has_job]) |> Map.put(:last_moved, db_world.day)
                  | &1
                ]
              )
            else
              acc2
            end
          end)
        else
          acc
        end
      end)

    # add non-lookers back
    updated_citizens_by_id_5 =
      if unemployed_split_2 != [] do
        Enum.reduce(unemployed_split_2, updated_citizens_by_id_4, fn citizen, acc ->
          acc
          |> Map.update!(
            citizen.town_id,
            &[
              citizen |> Map.drop([:town_id, :has_job]) |> Map.put(:last_moved, db_world.day) | &1
            ]
          )
        end)
      else
        updated_citizens_by_id_4
      end

    # IO.inspect(preferred_locations_by_level[0].slots)
    # ^ I think these should work as a substitute for job_and_housing_slots_normalized[x].job_and_housing_slots
    # ok these are…

    vacated_slots_2 =
      Enum.flat_map(unemployed_preferred_locations_by_level, fn {_level, preferred_locations} ->
        preferred_locations.choices
        |> Enum.filter(fn {citizen, city_id} -> citizen.town_id != city_id end)
        |> Enum.map(fn {citizen, _city_id} -> citizen.town_id end)
      end)

    occupied_slots_2 =
      Enum.flat_map(unemployed_preferred_locations_by_level, fn {_level, preferred_locations} ->
        preferred_locations.choices
        |> Enum.filter(fn {citizen, city_id} -> citizen.town_id != city_id end)
        |> Enum.map(fn {_citizen, city_id} -> city_id end)
      end)

    vacated_freq_2 = Enum.frequencies(vacated_slots_2)
    occupied_freq_2 = Enum.frequencies(occupied_slots_2)

    housing_slots_3 =
      housing_slots_2
      |> Map.merge(vacated_freq_2, fn _k, v1, v2 -> v1 - v2 end)
      |> Map.merge(occupied_freq_2, fn _k, v1, v2 -> v1 + v2 end)

    # NEW UNHOUSED CODE —————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————

    unhoused_citizens_split =
      Map.new(5..0, fn x ->
        {x,
         Enum.split(
           Enum.filter(unhoused_citizens, fn cit -> cit.education == x end),
           Enum.sum(Map.values(unemployed_preferred_locations_by_level[x].slots))
         )}
      end)

    unhoused_preferred_locations_by_level =
      Map.new(5..0, fn level ->
        {level,
         Enum.reduce(
           elem(unhoused_citizens_split[level], 0),
           %{
             choices: [],
             slots: unemployed_preferred_locations_by_level[level].slots
           },
           fn citizen, acc ->
             chosen_city =
               Enum.reduce(acc.slots, %{chosen_id: citizen.town_id, top_score: -1}, fn {city_id,
                                                                                        count},
                                                                                       acc2 ->
                 score =
                   if count > 0 do
                     Float.round(
                       citizen_score(
                         Citizens.preset_preferences()[citizen.preferences],
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
               if acc.slots != %{} && chosen_city.chosen_id != citizen.town_id do
                 acc.slots
                 |> Map.update!(chosen_city.chosen_id, &(&1 - 1))
                 |> Map.update(citizen.town_id, 0, &(&1 + 1))
               else
                 acc.slots
               end

             %{
               choices: acc.choices ++ [{citizen, chosen_city.chosen_id}],
               slots: updated_slots
             }
           end
         )}
      end)

    # find a way to return these to origin city
    unhoused_split_2 =
      Enum.reduce(unhoused_citizens_split, [], fn {_k, v}, acc ->
        acc ++ elem(v, 1)
      end)

    # ^ array of citizens who are still looking, that didn't make it into the level-specific comparisons

    # update the citizen's choice
    updated_citizens_by_id_6 =
      Enum.reduce(5..0, updated_citizens_by_id_5, fn x, acc ->
        if unhoused_preferred_locations_by_level[x].choices != [] do
          Enum.reduce(unhoused_preferred_locations_by_level[x].choices, acc, fn {citizen,
                                                                                 chosen_city_id},
                                                                                acc2 ->
            if citizen.town_id != chosen_city_id do
              acc2
              |> Map.update!(
                chosen_city_id,
                &[
                  citizen |> Map.drop([:town_id, :has_job]) |> Map.put(:last_moved, db_world.day)
                  | &1
                ]
              )
            else
              acc2
            end
          end)
        else
          acc
        end
      end)

    # add non-lookers back

    # IO.inspect(preferred_locations_by_level[0].slots)
    # ^ I think these should work as a substitute for job_and_housing_slots_normalized[x].job_and_housing_slots
    # ok these are…

    vacated_slots_3 =
      Enum.flat_map(unhoused_preferred_locations_by_level, fn {_level, preferred_locations} ->
        preferred_locations.choices
        |> Enum.filter(fn {citizen, city_id} -> citizen.town_id != city_id end)
        |> Enum.map(fn {citizen, _city_id} -> citizen.town_id end)
      end)

    occupied_slots_3 =
      Enum.flat_map(unhoused_preferred_locations_by_level, fn {_level, preferred_locations} ->
        preferred_locations.choices
        |> Enum.filter(fn {citizen, city_id} -> citizen.town_id != city_id end)
        |> Enum.map(fn {_citizen, city_id} -> city_id end)
      end)

    vacated_freq_3 = Enum.frequencies(vacated_slots_3)
    occupied_freq_3 = Enum.frequencies(occupied_slots_3)

    housing_slots_4 =
      housing_slots_3
      |> Map.merge(vacated_freq_3, fn _k, v1, v2 -> v1 - v2 end)
      |> Map.merge(occupied_freq_3, fn _k, v1, v2 -> v1 + v2 end)

    # shape: [city_id, city_id, city_id]
    # subtract these from housing_slots
    # ok this is an array of… I think… housing to remove from those cities
    # this means a job was taken from second elem, and giving housing to the first one
    # yes
    # adjust housing_slots here

    # IO.inspect(occupied_slots, label: "occupied")
    # IO.inspect(job_and_housing_slots_normalized)

    # have to subtract from housing_slots and run again

    # ok gotta make an updated slots thingy

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 1.5: MOVE UNEMPLOYED CITIZENS
    # ——————————————————————————————————————————————————————————————————————————————————

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 2: MOVE CITIZENS ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    # this produces a list of cities that have been occupied
    # this could also be in ETS

    # take housing slots, remove any city that was occupied previously
    slots_after_job_migrations = housing_slots_4

    housing_slots_expanded =
      Enum.reduce(
        housing_slots_4,
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

    slots_after_job_filtered =
      Enum.filter(housing_slots_4, fn {_k, v} -> v > 0 end) |> Enum.into(%{})

    housing_slots_left = Enum.sum(Map.values(housing_slots_4))

    IO.inspect(housing_slots_4)

    unhoused_split_3 = unhoused_split_2 |> Enum.split(housing_slots_left)

    # SHAPE OF unhoused_locations.choices is an array of {citizen, city_id}
    unhoused_preferred_locations =
      Enum.reduce(
        elem(unhoused_split_3, 0),
        %{choices: [], slots: slots_after_job_filtered},
        fn citizen, acc ->
          chosen_city =
            Enum.reduce(acc.slots, %{chosen_id: citizen.town_id, top_score: -1}, fn {city_id,
                                                                                     count},
                                                                                    acc2 ->
              score =
                if count > 0 do
                  Float.round(
                    citizen_score(
                      Citizens.preset_preferences()[citizen.preferences],
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
            if acc.slots != %{} && chosen_city.chosen_id != citizen.town_id do
              acc.slots
              |> Map.update!(chosen_city.chosen_id, &(&1 - 1))
              |> Map.update(citizen.town_id, 1, &(&1 + 1))
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

    updated_citizens_by_id_7 =
      Enum.reduce(unhoused_preferred_locations.choices, updated_citizens_by_id_6, fn {citizen,
                                                                                      chosen_city_id},
                                                                                     acc ->
        if citizen.town_id != chosen_city_id do
          acc |> Map.update!(chosen_city_id, &[citizen | &1])
        else
          acc
        end
      end)

    # # ——————————————————————————————————————————————————————————————————————————————————
    # # ————————————————————————————————————————— ROUND 3: MOVE CITIZENS WITHOUT HOUSING ANYWHERE THERE IS HOUSING
    # # ——————————————————————————————————————————————————————————————————————————————————

    # occupied_slots_4 =
    #   Enum.map(unhoused_preferred_locations.choices, fn {_citizen_id, city_id} ->
    #     city_id
    #   end)

    # slots_after_housing_migrations =
    #   if slots_after_job_migrations == %{} do
    #     %{}
    #   else
    #     Enum.reduce(occupied_slots_2, slots_after_job_migrations, fn city_id, acc ->
    #       # need to find the right key, these cities are already normalized
    #       if is_nil(city_id) do
    #         acc
    #       else
    #         # key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
    #         Map.update!(acc, city_id, &(&1 - 1))
    #         # TODO
    #         # this seems like something that could be done with ETS
    #       end
    #     end)
    #   end

    # housing_slots_2_expanded =
    #   Enum.reduce(
    #     slots_after_housing_migrations,
    #     [],
    #     fn {city_id, slots_count}, acc ->
    #       # duplicate this score v times (1 for each slot)

    #       if slots_count > 0 do
    #         acc ++ for _ <- 1..slots_count, do: city_id
    #       else
    #         acc
    #       end
    #     end
    #   )

    # unhoused_split_3 = unhoused_split_2 |> Enum.split(length(housing_slots_2_expanded))

    # slots_filtered =
    #   Enum.filter(slots_after_housing_migrations, fn {_k, v} -> v > 0 end) |> Enum.into(%{})

    # # SHAPE OF unhoused_locations.choices is an array of {citizen, city_id}
    # unhoused_locations =
    #   Enum.reduce(elem(unhoused_split_3, 0), %{choices: [], slots: slots_filtered}, fn citizen,
    #                                                                                  acc ->
    #     chosen_city =
    #       Enum.reduce(acc.slots, %{chosen_id: 0, top_score: 0}, fn {city_id, count}, acc2 ->
    #         score =
    #           if count > 0 do
    #             Float.round(
    #               citizen_score(
    #                 Citizens.preset_preferences()[citizen.preferences],
    #                 citizen.education,
    #                 slotted_cities_by_id[city_id]
    #               ),
    #               4
    #             )
    #           else
    #             0
    #           end

    #         if score > acc2.top_score do
    #           %{
    #             chosen_id: city_id,
    #             top_score: score
    #           }
    #         else
    #           acc2
    #         end
    #       end)

    #     updated_slots =
    #       if chosen_city.chosen_id > 0 do
    #         if acc.slots[chosen_city.chosen_id] > 0 do
    #           Map.update!(acc.slots, chosen_city.chosen_id, &(&1 - 1))
    #         else
    #           Map.drop(acc.slots, [chosen_city.chosen_id])
    #         end
    #       else
    #         acc.slots
    #       end

    #     %{
    #       choices:
    #         if chosen_city.chosen_id == 0 do
    #           acc.choices
    #         else
    #           acc.choices ++ [{citizen, chosen_city.chosen_id}]
    #         end,
    #       slots: updated_slots
    #     }
    #   end)

    # updated_citizens_by_id_5 =
    #   Enum.reduce(unhoused_locations.choices, updated_citizens_by_id_4, fn {citizen,
    #                                                                         chosen_city_id},
    #                                                                        acc ->
    #     if citizen.town_id != chosen_city_id do
    #       acc |> Map.update!(chosen_city_id, &[citizen | &1])
    #     else
    #       acc
    #     end
    #   end)

    # updated_edu_logs =
    #   Map.merge(CityHelpers.integerize_keys(city.logs_edu), city.educated_citizens, fn _k,
    #                                                                                    v1,
    #                                                                                    v2 ->
    #     v1 + v2
    #   end)

    # :logs_emigration_housing,
    # :logs_emigration_taxes,
    # :logs_emigration_jobs,
    # :logs_immigration,
    # :logs_attacks,
    # :logs_deaths_housing,
    # :logs_deaths_attacks,

    # filter updated_citizens to remove jas_job and town_id before going in the DB

    updated_citizens_by_id_7
    |> Enum.chunk_every(20)
    |> Enum.each(fn chunk ->
      Repo.checkout(
        # each comes with a city_id and a list of citizens
        fn ->
          Enum.each(chunk, fn {id, list} ->
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
        end,
        timeout: 6_000_000
      )
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

    # SEND RESULTS TO CLIENTS
    # send val to liveView process that manages front-end; this basically sends to every client.
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "pong",
      db_world
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 5000)

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
    (1 - normalized_city.tax_rates[to_string(education_level)]) * citizen_preferences.tax_rates +
      (1 - normalized_city.pollution_normalized) * citizen_preferences.pollution +
      (1 - normalized_city.sprawl_normalized) * citizen_preferences.sprawl +
      normalized_city.fun_normalized * citizen_preferences.fun +
      normalized_city.health_normalized * citizen_preferences.health
  end
end