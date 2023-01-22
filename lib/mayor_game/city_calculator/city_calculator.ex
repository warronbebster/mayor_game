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

    IO.inspect(length(Map.keys(leftovers.housing_slots)), label: "housing_left")

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
    job_and_housing_slots_normalized =
      Enum.reduce(leftovers.housing_slots, level_slots, fn {city, slots_count}, acc ->
        normalized_city =
          normalize_city(
            city,
            leftovers.fun_max,
            leftovers.health_max,
            leftovers.pollution_max,
            leftovers.sprawl_max
          )

        slots_per_level =
          Enum.reduce(city.jobs, %{slots_count: slots_count}, fn {level, count}, acc2 ->
            if acc2.slots_count > 0 do
              level_slots_count = min(count, slots_count)

              acc2
              |> Map.update!(
                :slots_count,
                &(&1 - level_slots_count)
              )
              |> Map.put(level, {normalized_city, level_slots_count})
            else
              acc2
              |> Map.put(level, {normalized_city, 0})
            end
          end)
          |> Map.drop([:slots_count])

        # for each level in slots_per_level
        #

        Enum.map(0..5, fn x ->
          {x,
           %{
             normalized_cities: acc[x].normalized_cities ++ [slots_per_level[x]],
             total_slots: acc[x].total_slots + elem(slots_per_level[x], 1),
             slots_expanded:
               acc[x].slots_expanded ++ Enum.map(1..elem(slots_per_level[x], 1), fn _ -> city end)
           }}
        end)
        |> Enum.into(%{})
      end)

    IO.inspect('after job slots per level calculated')

    citizens_split =
      Map.new(0..5, fn x ->
        {x,
         Enum.split(
           Enum.filter(leftovers.citizens_looking, fn cit -> cit.education == x end),
           job_and_housing_slots_normalized[x].total_slots
         )}
      end)

    # split looking

    preference_maps_by_level =
      Map.new(0..5, fn x ->
        {x,
         Enum.map(
           elem(citizens_split[x], 0),
           fn citizen ->
             Enum.flat_map(job_and_housing_slots_normalized[x].normalized_cities, fn {k, v} ->
               # duplicate this score v times (1 for each slot)

               score =
                 Float.round(1 - citizen_score(citizen.preferences, citizen.education, k), 4)

               for _ <- 1..v,
                   do: score
             end)
           end
         )}
      end)

    looking_but_not_in_job_race =
      Enum.reduce(citizens_split, [], fn {_k, v}, acc ->
        acc ++ elem(v, 1)
      end)

    # array of citizens who are still looking, that didn't make it into the level-specific comparisons

    # if not empty
    # run hungarian
    #
    hungarian_results_by_level =
      Map.new(0..5, fn x ->
        {x,
         if(preference_maps_by_level[x] != [],
           do: compute_destination(preference_maps_by_level[x]),
           else: %{matrix: [], output: []}
         )}
      end)

    # MULTI CHANGESET MOVE JOB SEARCHING CITIZENS
    # MOVE CITIZENS
    # Enum.map(0..5, fn x ->
    #   if hungarian_results_by_level[x].output != [] do
    #     hungarian_results_by_level[x].output
    #     |> Enum.reduce(Ecto.Multi.new(), fn {citizen_index, slot_index}, multi ->
    #       citizen = Enum.at(elem(citizens_split[x], 0), citizen_index)
    #       town_from = City.get_town!(citizen.town_id)

    #       town_to =
    #         City.get_town!(
    #           Enum.at(job_and_housing_slots_normalized[x].slots_expanded, slot_index).id
    #         )

    #       if town_from.id != town_to.id do
    #         citizen_changeset =
    #           citizen
    #           |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

    #         log_from =
    #           CityHelpersTwo.describe_citizen(citizen) <>
    #             " has moved to " <> town_to.title

    #         log_to =
    #           CityHelpersTwo.describe_citizen(citizen) <>
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

    #         Ecto.Multi.update(multi, {:update_citizen_town, citizen_index}, citizen_changeset)
    #         |> Ecto.Multi.update({:update_town_from, citizen_index}, town_from_changeset)
    #         |> Ecto.Multi.update({:update_town_to, citizen_index}, town_to_changeset)
    #       else
    #         multi
    #       end
    #     end)
    #     |> Repo.transaction()
    #   end
    # end)

    IO.inspect("round 1 done")

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 2: MOVE CITIZENS ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    # this produces a list of cities that have been occupied
    occupied_slots =
      Enum.flat_map(hungarian_results_by_level, fn {level, results_list} ->
        Enum.map(results_list.output, fn {_citizen_id, city_id} ->
          Enum.at(job_and_housing_slots_normalized[level].slots_expanded, city_id)

          # could also potentially move the citizens here
          # could move citizens here
          # COULD MOVE CITIZENS HERE ———————————————————————————————————
        end)
      end)

    # take housing slots, remove any city that was occupied previously
    slots_after_job_migrations =
      if leftovers.housing_slots == %{} do
        %{}
      else
        Enum.reduce(occupied_slots, leftovers.housing_slots, fn city, acc ->
          # need to find the right key, these cities are already normalized
          if is_nil(city) do
            acc
          else
            key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
            Map.update!(acc, key, &(&1 - 1))
          end
        end)
      end

    housing_slots_normalized =
      Enum.map(slots_after_job_migrations, fn {k, v} ->
        {normalize_city(
           k,
           leftovers.fun_max,
           leftovers.health_max,
           leftovers.pollution_max,
           leftovers.sprawl_max
         ), v}
      end)

    housing_slots_expanded =
      Enum.flat_map(housing_slots_normalized, fn {k, v} ->
        # duplicate this score v times (1 for each slot)

        for _ <- 1..v,
            do: k
      end)

    preference_maps =
      Enum.map(looking_but_not_in_job_race, fn citizen ->
        Enum.flat_map(housing_slots_normalized, fn {k, v} ->
          # duplicate this score v times (1 for each slot)

          score = Float.round(1 - citizen_score(citizen.preferences, citizen.education, k), 4)

          for _ <- 1..v,
              do: score
        end)
      end)

    hungarian_results =
      if preference_maps != [],
        do: compute_destination(preference_maps),
        else: %{matrix: [], output: []}

    # pass in list of lists
    # firs tlist index is citizen index
    # second tier is cities
    # [
    #   [.5, .6, .7]
    # ]

    # returns list of [{citizen_index, city_index}]

    # MULTI CHANGESET MOVE LOOKING CITIZENS
    # MOVE CITIZENS
    # if hungarian_results.output != [] do
    #   hungarian_results.output
    #   |> Enum.reduce(Ecto.Multi.new(), fn {citizen_index, slot_index}, multi ->
    #     citizen = Enum.at(looking_but_not_in_job_race, citizen_index)
    #     town_from = City.get_town!(citizen.town_id)
    #     town_to = City.get_town!(Enum.at(housing_slots_expanded, slot_index).id)

    #     if town_from.id != town_to.id do
    #       citizen_changeset =
    #         citizen
    #         |> City.Citizens.changeset(%{town_id: town_to.id, town: town_to})

    #       log_from =
    #         CityHelpersTwo.describe_citizen(citizen) <>
    #           " has moved to " <> town_to.title

    #       log_to =
    #         CityHelpersTwo.describe_citizen(citizen) <>
    #           " has moved from " <> town_from.title

    #       # if list is longer than 50, remove last item
    #       limited_log_from = update_logs(log_from, town_from.logs)
    #       limited_log_to = update_logs(log_to, town_to.logs)

    #       town_from_changeset =
    #         town_from
    #         |> City.Town.changeset(%{logs: limited_log_from})

    #       town_to_changeset =
    #         town_to
    #         |> City.Town.changeset(%{logs: limited_log_to})

    #       Ecto.Multi.update(multi, {:update_citizen_town, citizen_index}, citizen_changeset)
    #       |> Ecto.Multi.update({:update_town_from, citizen_index}, town_from_changeset)
    #       |> Ecto.Multi.update({:update_town_to, citizen_index}, town_to_changeset)
    #     else
    #       multi
    #     end
    #   end)
    #   |> Repo.transaction()
    # end

    IO.inspect("round 2 done")

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— ROUND 3: MOVE CITIZENS WITHOUT HOUSING ANYWHERE THERE IS HOUSING
    # ——————————————————————————————————————————————————————————————————————————————————

    occupied_slots_2 =
      Enum.map(hungarian_results.output, fn {_citizen_id, city_id} ->
        Enum.at(housing_slots_expanded, city_id)
      end)

    slots_after_housing_migrations =
      if slots_after_job_migrations == %{} do
        %{}
      else
        Enum.reduce(occupied_slots_2, slots_after_job_migrations, fn city, acc ->
          # need to find the right key, these cities are already normalized
          key = Enum.find(Map.keys(acc), fn x -> x.id == city.id end)
          Map.update!(acc, key, &(&1 - 1))
        end)
      end

    housing_slots_3_normalized =
      Enum.map(slots_after_housing_migrations, fn {k, v} ->
        {normalize_city(
           k,
           leftovers.fun_max,
           leftovers.health_max,
           leftovers.pollution_max,
           leftovers.sprawl_max
         ), v}
      end)

    housing_slots_3_expanded =
      Enum.flat_map(housing_slots_3_normalized, fn {k, v} ->
        # duplicate this score v times (1 for each slot)

        for _ <- 1..v,
            do: k
      end)

    unhoused_split =
      Enum.shuffle(leftovers.unhoused_citizens) |> Enum.split(length(housing_slots_3_expanded))

    unhoused_preference_maps =
      Enum.map(elem(unhoused_split, 0), fn citizen ->
        Enum.flat_map(housing_slots_3_normalized, fn {k, v} ->
          # duplicate this score v times (1 for each slot)

          score = Float.round(1 - citizen_score(citizen.preferences, citizen.education, k), 4)

          for _ <- 1..v,
              do: score
        end)
      end)

    hungarian_results_unhoused =
      if unhoused_preference_maps != [],
        do: compute_destination(unhoused_preference_maps),
        else: %{matrix: [], output: []}

    if hungarian_results_unhoused.output != [] do
      hungarian_results_unhoused.output
      |> Enum.reduce(Ecto.Multi.new(), fn {citizen_index, slot_index}, multi ->
        citizen = Enum.at(elem(unhoused_split, 0), citizen_index)
        town_from = City.get_town!(citizen.town_id)
        town_to = City.get_town!(Enum.at(housing_slots_3_expanded, slot_index).id)

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

          Ecto.Multi.update(multi, {:update_citizen_town, citizen_index}, citizen_changeset)
          |> Ecto.Multi.update({:update_town_from, citizen_index}, town_from_changeset)
          |> Ecto.Multi.update({:update_town_to, citizen_index}, town_to_changeset)
        else
          multi
        end
      end)
      |> Repo.transaction()
    end

    # MULTI KILL REST OF UNHOUSED CITIZENS
    elem(unhoused_split, 1)
    |> Enum.with_index()
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

    #

    # unhoused_citizens (no anything)

    IO.inspect("round 3 done")

    # ——————————————————————————————————————————————————————————————————————————————————
    # ————————————————————————————————————————— OTHER ECTO UPDATES
    # ——————————————————————————————————————————————————————————————————————————————————

    # MULTI UPDATE: update city money/treasury in DB
    leftovers.all_cities_new
    |> Enum.with_index()
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

    # MULTI CHANGESET EDUCATE

    leftovers.citizens_learning
    |> Enum.map(fn {level, list} ->
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

    # MULTI CHANGESET AGE
    Repo.update_all(MayorGame.City.Citizens, inc: [age: 1])

    # MULTI CHANGESET KILL OLD CITIZENS
    leftovers.citizens_too_old
    |> Enum.with_index()
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

    # MULTI KILL POLLUTED CITIZENS
    leftovers.citizens_polluted
    |> Enum.with_index()
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

    # MULTI REPRODUCE
    leftovers.citizens_to_reproduce
    |> Enum.with_index()
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
