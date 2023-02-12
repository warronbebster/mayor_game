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
    cities_count = Enum.count(cities)

    pollution_ceiling = 2_000_000_000 * Random.gammavariate(7.5, 1)

    db_world = City.get_world!(1)

    IO.puts(
      "day: " <>
        to_string(db_world.day) <>
        " | cities: " <>
        to_string(cities_count) <>
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

    cities_list = Enum.shuffle(cities)

    # :eprof.start_profiling([self()])

    leftovers =
      cities_list
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

    citizens_looking =
      List.flatten(
        Enum.map(leftovers, fn city ->
          city.housed_unemployed_citizens ++ city.housed_employed_looking_citizens
        end)
      )

    citizens_polluted = List.flatten(Enum.map(leftovers, fn city -> city.polluted_citizens end))

    citizens_to_reproduce =
      List.flatten(Enum.map(leftovers, fn city -> city.reproducing_citizens end))

    unhoused_citizens = List.flatten(Enum.map(leftovers, fn city -> city.unhoused_citizens end))
    new_world_pollution = Enum.sum(Enum.map(leftovers, fn city -> city.pollution end))
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

    citizens_learning = %{
      1 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[1] end)),
      2 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[2] end)),
      3 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[3] end)),
      4 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[4] end)),
      5 => List.flatten(Enum.map(leftovers, fn city -> city.educated_citizens[5] end))
    }

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
      |> Map.new(fn city -> {city.id, city} end)

    repo_work = %{
      repo_city_logs: Map.new(cities_list, fn city -> {city.id, city.logs} end),
      repo_multi: Ecto.Multi.new()
    }

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
      repo_work =
        Enum.reduce(0..5, repo_work, fn x, repo_0 ->
          if preferred_locations_by_level[x].choices != [], do:
            preferred_locations_by_level[x].choices
            |> Enum.reduce(repo_work, fn {citizen, city_id}, repo ->
              town_from = struct(Town, slotted_cities_by_id[citizen.town_id].city)
              town_to = struct(Town, slotted_cities_by_id[city_id].city)

              if town_from.id != town_to.id do
                citizen_changeset =
                  citizen
                  |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

                log_from =
                  stringify_year_and_day(db_world.day) <> " : " <>
                    CityHelpers.describe_citizen(citizen) <>
                    " has moved to " <> town_to.title <> 
                    " for better job prospects"

                log_to =
                  stringify_year_and_day(db_world.day) <> " : " <>
                    CityHelpers.describe_citizen(citizen) <>
                    " has moved from " <> town_from.title <> 
                    " for better job prospects"

                %{
                  repo_city_logs: repo.repo_city_logs |> Map.put(town_from.id, update_logs(log_from, repo.repo_city_logs[town_from.id])) |> Map.put(town_to.id, update_logs(log_to, repo.repo_city_logs[town_to.id])), 
                  repo_multi: repo.repo_multi |> Ecto.Multi.update({:update_citizen_town, citizen.id}, citizen_changeset)
                }
              else
                repo
              end
            end),
            else: repo_0
        end)

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
              Enum.reduce(acc.slots, %{chosen_id: 0, top_score: -1}, fn {city_id, count},
                                                                        acc2 ->
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

      repo_work =
        if preferred_locations.choices != [], do:
          preferred_locations.choices
          |> Enum.reduce(repo_work, fn {citizen, city_id}, repo ->
              town_from = struct(Town, slotted_cities_by_id[citizen.town_id].city)
              town_to = struct(Town, slotted_cities_by_id[city_id].city)

              if town_from.id != town_to.id do
                citizen_changeset =
                  citizen
                  |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

                log_from =
                  stringify_year_and_day(db_world.day) <> " : " <>
                    CityHelpers.describe_citizen(citizen) <>
                    " has moved to " <> town_to.title <>
                    " due to living preferences"

                log_to =
                  stringify_year_and_day(db_world.day) <> " : " <>
                    CityHelpers.describe_citizen(citizen) <>
                    " has moved from " <> town_from.title <> 
                    " due to living preferences"

                %{
                  repo_city_logs: repo.repo_city_logs |> Map.put(town_from.id, update_logs(log_from, repo.repo_city_logs[town_from.id])) |> Map.put(town_to.id, update_logs(log_to, repo.repo_city_logs[town_to.id])), 
                  repo_multi: repo.repo_multi |> Ecto.Multi.update({:update_citizen_town, citizen.id}, citizen_changeset)
                }
              else
                repo
              end
            end),
            else: repo_work

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

# IO.inspect(unhoused_citizens)


      unhoused_split =
        Enum.shuffle(unhoused_citizens)
         |> Enum.split(length(housing_slots_2_expanded))

# IO.inspect(unhoused_split)

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

          IO.puts("unhoused_locations: Lvl " <> to_string(citizen.education) <> " chose city " <> to_string(chosen_city.chosen_id))

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

      repo_work = 
        if unhoused_locations.choices != [], do:
          unhoused_locations.choices
          |> Enum.reduce(repo_work, fn {citizen, city_id}, repo ->
              # citizen = Enum.at(elem(unhoused_split, 0), citizen_index)
              town_from = struct(Town, slotted_cities_by_id[citizen.town_id].city)
              town_to = struct(Town, slotted_cities_by_id[city_id].city)
      
              if town_from.id != town_to.id do
              citizen_changeset =
                 citizen
                 |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})
      
               log_from =
                 stringify_year_and_day(db_world.day) <> " : " <>
                   CityHelpers.describe_citizen(citizen) <>
                   " has moved to " <> town_to.title <>
                   " due to lack of housing"
      
               log_to =
                 stringify_year_and_day(db_world.day) <> " : " <>
                   CityHelpers.describe_citizen(citizen) <>
                   " has moved from " <> town_from.title <>
                   " due to lack of housing"

               %{
                 repo_city_logs: repo.repo_city_logs |> Map.put(town_from.id, update_logs(log_from, repo.repo_city_logs[town_from.id])) |> Map.put(town_to.id, update_logs(log_to, repo.repo_city_logs[town_to.id])), 
                 repo_multi: repo.repo_multi |> Ecto.Multi.update({:update_citizen_town, citizen.id}, citizen_changeset)
               }
              else
                repo
              end
            end),
            else: repo_work

      # MULTI KILL REST OF UNHOUSED CITIZENS

      repo_work = 
        elem(unhoused_split, 1)
        |> Enum.reduce(repo_work, fn citizen, repo ->

          log = stringify_year_and_day(db_world.day) <> " : " <> citizen.name <> " died from lack of housing. RIP"
          %{
            repo_city_logs: repo.repo_city_logs |> Map.put(citizen.town_id, update_logs(log, repo.repo_city_logs[citizen.town_id])), 
            repo_multi: repo.repo_multi |> Ecto.Multi.delete_all({:delete_citizen, citizen.id}, from(c in Citizens, where: c.id == ^citizen.id))
          }
        end)

      #

      # ——————————————————————————————————————————————————————————————————————————————————
      # ————————————————————————————————————————— OTHER ECTO UPDATES
      # ——————————————————————————————————————————————————————————————————————————————————

      # MULTI UPDATE: update city money/treasury in DB ——————————————————————————————————————————————————— DB UPDATE

      # IF I MAKE THIS ATOMIC, DON'T NEED TO DO THIS
      # delete_all
      all_cities_recent =
        from(t in Town, select: [:treasury, :shields, :id])
        |> Repo.all()

      # IO.inspect(all_cities_recent)
      # ok this works
      # prints a list of cities

      all_cities_recent_by_id =
        all_cities_recent
        |> Map.new(fn city -> {city.id, city} end)

      repo_work = 
        leftovers
          |> Enum.reduce(repo_work, fn city, repo ->
            # updated_city = City.get_town!(city.id)
            newest_treasury = all_cities_recent_by_id[city.id].treasury
            # newest_shields = min(city.shields, all_cities_recent_by_id[city.id].shields)
            newest_shields =
              city.shields - city.loaded_shields + all_cities_recent_by_id[city.id].shields

            updated_city_treasury =
              if newest_treasury + city.income - city.daily_cost < 0,
                do: 0,
                else: newest_treasury + city.income - city.daily_cost

            town_struct =
              struct(
                Town,
                city
                |> Map.put(:pollution, -1)
                |> Map.put(:citizen_count, -1)
                |> Map.put(:steel, -1)
                # |> Map.put(:treasury, 0)
                |> Map.put(:missiles, -1)
                |> Map.put(:sulfur, -1)
                |> Map.put(:gold, -1)
                |> Map.put(:uranium, -1)
                |> Map.put(:shields, -1)
              )

            updated_attrs = %{
              treasury: updated_city_treasury,
              steel: city.steel,
              missiles: city.missiles,
              sulfur: city.sulfur,
              gold: city.gold,
              pollution: city.pollution,
              uranium: city.uranium,
              shields: newest_shields,
              citizen_count: city.citizen_count
            }

            # I could make all these atomic
            # then i don't think I'd need to fetch these from the DB again here in all_cities_recent

            # ok this works

            # if city.id == 2 do
            #   IO.inspect(town_struct)
            #   IO.inspect(Map.merge(updated_attrs, synced_count))
            # end

            if :rand.uniform() > city.citizen_count + 1 / 10 do
              town_update_changeset = City.Town.changeset(town_struct, updated_attrs)
              log = stringify_year_and_day(db_world.day) <> " : A citizen has moved here"
              create_citizen_changeset =
                City.create_citizens_changeset(%{
                  town_id: city.id,
                  age: 0,
                  education: 0,
                  has_job: false,
                  last_moved: db_world.day
                })

              %{
                repo_city_logs: repo.repo_city_logs |> Map.put(city.id, update_logs(log, repo.repo_city_logs[city.id])), 
                repo_multi: repo.repo_multi |> Ecto.Multi.insert({:add_citizen, city.id + 1}, create_citizen_changeset) |> Ecto.Multi.update({:update_towns, city.id}, town_update_changeset)
              }
            else
              town_update_changeset = City.Town.changeset(town_struct, updated_attrs)

              %{
                repo_city_logs: repo.repo_city_logs, 
                repo_multi: repo.repo_multi |> Ecto.Multi.update({:update_towns, city.id}, town_update_changeset)
              }
            end
          end)

      # MULTI CHANGESET EDUCATE ——————————————————————————————————————————————————— DB UPDATE

      # Repo.update_all(Track, ​set:​ [​number_of_plays:​ 0])

      # citizens_learning[1]
      # test = [1, 4]

      # IO.inspect(cs)

      # if rem(world.day, 365) == 0 do

      repo_work = 
        citizens_learning
          |> Enum.reduce(repo_work, fn {level, list}, repo_0 ->
            list
            |> Enum.reduce(repo_0, fn citizen, repo ->
              log = stringify_year_and_day(db_world.day) <> " : " <> citizen.name <> " graduated to level " <> to_string(level)
              citizen_changeset =
                citizen
                |> City.Citizens.changeset(%{education: level})
              %{
                repo_city_logs: repo.repo_city_logs |> Map.put(citizen.town_id, update_logs(log, repo.repo_city_logs[citizen.town_id])), 
                repo_multi: repo.repo_multi |> Ecto.Multi.update({:update_citizen, citizen.id}, citizen_changeset) 
              }
            end)
          end)

      # end

      # end)

      # MULTI CHANGESET AGE

      Repo.update_all(MayorGame.City.Citizens, inc: [age: 1])

      # MULTI CHANGESET KILL OLD CITIZENS ——————————————————————————————————————————————————— DB UPDATE
      repo_work = 
        citizens_too_old
          |> Enum.reduce(repo_work, fn citizen, repo ->

          log = stringify_year_and_day(db_world.day) <> " : " <> citizen.name <> " died from old age. RIP"
          %{
            repo_city_logs: repo.repo_city_logs |> Map.put(citizen.town_id, update_logs(log, repo.repo_city_logs[citizen.town_id])), 
            repo_multi: repo.repo_multi |> Ecto.Multi.delete_all({:delete_citizen, citizen.id}, from(c in Citizens, where: c.id == ^citizen.id)) 
          }
        end)

      # end)

      # MULTI KILL POLLUTED CITIZENS ——————————————————————————————————————————————————— DB UPDATE
      repo_work = 
        citizens_polluted
          |> Enum.reduce(repo_work, fn citizen, repo ->

          log = stringify_year_and_day(db_world.day) <> " : " <> citizen.name <> " died from pollution. RIP"
          %{
            repo_city_logs: repo.repo_city_logs |> Map.put(citizen.town_id, update_logs(log, repo.repo_city_logs[citizen.town_id])), 
            repo_multi: repo.repo_multi |> Ecto.Multi.delete_all({:delete_citizen, citizen.id}, from(c in Citizens, where: c.id == ^citizen.id)) 
          }
        end)

      # MULTI REPRODUCE ——————————————————————————————————————————————————— DB UPDATE

      now_utc = DateTime.truncate(DateTime.utc_now(), :second)
      repo_work = 
        citizens_to_reproduce
          |> Enum.reduce(repo_work, fn citizen, repo ->

          new_name = Faker.Person.name()
          create_citizen_changeset =
              City.create_citizens_changeset(%{
                town_id: citizen.town_id,
                age: 0,
                education: 0,
                has_job: false,
                last_moved: db_world.day,
                name: new_name,
                preferences: CityHelpers.create_citizen_preference_map(),
                inserted_at: now_utc,
                updated_at: now_utc
              })
 
          log = stringify_year_and_day(db_world.day) <> " : " <> new_name <> " was born"
          %{
            repo_city_logs: repo.repo_city_logs |> Map.put(citizen.town_id, update_logs(log, repo.repo_city_logs[citizen.town_id])), 
            repo_multi: repo.repo_multi |> Ecto.Multi.insert({:insert_citizen, citizen.id}, create_citizen_changeset) 
          }
        end)

    Repo.checkout(
      fn ->
        Enum.reduce(repo_work.repo_city_logs, repo_work.repo_multi, fn {id, log}, multi ->
          town = City.get_town!(id)
          town_changeset =
            town
            |> City.Town.changeset(%{logs: log})
          Ecto.Multi.update(multi, {:update_town_logs, id}, town_changeset)
        end)
         |> Repo.transaction(timeout: 60_000)
      end,
      timeout: 6_000_000
    )

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

    if length(updated_log) > 250 do
      updated_log |> Enum.take(250)
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
  
  def stringify_year_and_day(day) do
    "Year " <> to_string(div(day, 365)) <> " Day " <> to_string(rem(day, 365))
  end
end
