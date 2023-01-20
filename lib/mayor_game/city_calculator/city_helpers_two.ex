defmodule MayorGame.CityHelpersTwo do
  alias MayorGame.City
  alias MayorGame.City.{Citizens, Town, Buildable, Details, CombinedBuildable, World}

  @doc """
    takes a %Town{} struct and %World{} struct

    returns a map:
    ```
    %{
      city: city_update,
      workers: total_workers,
      education: total_education,
      tax: 0,
      housing: total_housing,
      money: money,
      area: area.total_area,
      sprawl: area.sprawl,
      energy: energy.total_energy,
      pollution: energy.pollution,
      citizens_looking: []
    }
    ```
  """
  def calculate_city_stats(%Town{} = city, %World{} = world, cities_count, pollution_ceiling) do
    city_preloaded = preload_city_check(city)

    # reset buildables status in database
    # this might end up being redundant because I can construct that status and not check it from the DB
    # city_reset = reset_buildables_to_enabled(city_preloaded)

    # ayyy this is successfully combining the buildables
    # next step is applying the upgrades (done)
    # and putting it in city_preloaded
    city_baked_details = %{city_preloaded | details: bake_details(city_preloaded.details)}

    all_buildables = city_baked_details.details |> Map.take(Buildable.buildables_list())

    # this is a map
    # I can either re-order this (JK, maps are unordered)

    # I think this looks like a keyword list with {type of buildable, list of actual buildables}
    ordered_buildables =
      Enum.map(Buildable.buildables_ordered_flat(), fn x -> {x, all_buildables[x]} end)

    sorted_citizens = Enum.sort_by(city_baked_details.citizens, & &1.education, :desc)

    # buildables_ordered is in order
    results =
      Enum.reduce(
        ordered_buildables,
        %{
          money: city_baked_details.details.city_treasury,
          income: 0,
          daily_cost: 0,
          citizens: sorted_citizens,
          employed_citizens: [],
          fun: 0,
          health: 0,
          total_housing: 0,
          housing: 0,
          total_energy: 0,
          energy: 0,
          pollution: 0,
          jobs: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
          total_jobs: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
          education: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
          total_area: 0,
          area: 0,
          buildables: ordered_buildables,
          result_buildables: []
        },
        fn {buildable_type, buildable_array}, acc ->
          if buildable_array !== [] do
            # for each set of buildables

            # for each individual buildable:
            Enum.reduce(buildable_array, acc, fn individual_buildable, acc2 ->
              # if the building has no requirements
              # if building has requirements
              if individual_buildable.metadata.requires == nil do
                # generate final production map
                update_generated_acc(individual_buildable, length(acc.citizens), acc2)
              else
                reqs_minus_workers = Map.drop(individual_buildable.metadata.requires, [:workers])

                checked_reqs = check_reqs(reqs_minus_workers, acc2)

                if checked_reqs == [] do
                  if Map.has_key?(individual_buildable.metadata.requires, :workers) do
                    checked_workers =
                      check_workers(individual_buildable.metadata.requires, acc2.citizens)

                    enough_workers =
                      length(checked_workers) >=
                        individual_buildable.metadata.requires.workers.count

                    updated_buildable =
                      if !enough_workers do
                        individual_buildable
                        |> put_in([:buildable, :reason], [:workers])
                        |> put_in([:buildable, :enabled], false)
                        |> put_in(
                          [:metadata, :jobs],
                          individual_buildable.metadata.requires.workers.count -
                            length(checked_workers)
                        )
                      else
                        # if all conditions are met
                        individual_buildable
                        |> put_in([:metadata, :jobs], 0)
                      end

                    tax_earned =
                      round(
                        length(checked_workers) *
                          (1 + individual_buildable.metadata.requires.workers.level) * 100 *
                          city.tax_rates[
                            to_string(individual_buildable.metadata.requires.workers.level)
                          ] /
                          10
                      )

                    money_required =
                      if Map.has_key?(individual_buildable.metadata.requires, :money),
                        do: individual_buildable.metadata.requires.money,
                        else: 0

                    acc_after_workers =
                      if enough_workers,
                        do:
                          update_generated_acc(updated_buildable, length(acc.citizens), acc2)
                          |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
                          |> Map.put(:income, acc2.income + tax_earned)
                          |> Map.put(
                            :daily_cost,
                            acc2.daily_cost + money_required
                          )
                          |> Map.put(:money, acc2.money + tax_earned),
                        else:
                          acc2
                          |> Map.update!(:result_buildables, fn current ->
                            [updated_buildable | current]
                          end)

                    # update acc with disabled buildable

                    acc_after_workers
                    |> Map.update!(:employed_citizens, fn currently_employed ->
                      Enum.map(checked_workers, fn cit -> Map.put(cit, :has_job, true) end) ++
                        currently_employed
                    end)
                    |> Map.update!(:citizens, fn current_citizens ->
                      # this is where I need to filter by the job level
                      # I thought this would do it
                      current_citizens -- checked_workers
                    end)
                    |> Map.update!(:jobs, fn current_jobs_map ->
                      Map.update!(
                        current_jobs_map,
                        individual_buildable.metadata.requires.workers.level,
                        &(&1 + length(checked_workers))
                      )
                    end)
                    |> Map.update!(:total_jobs, fn current_total_jobs_map ->
                      Map.update!(
                        current_total_jobs_map,
                        individual_buildable.metadata.requires.workers.level,
                        &(&1 + individual_buildable.metadata.requires.workers.count)
                      )
                    end)

                    # if number is less than reqs.workers.count, buildable is disabled, reason workers
                    # add jobs equal to workers.count - length

                    # remove citizens from acc2.citizens
                    # add them to acc2.employed_citizens
                  else
                    # if it's operating fine & doesn't require workers

                    update_generated_acc(individual_buildable, length(acc.citizens), acc2)
                  end
                else
                  # if requirements not met
                  updated_buildable =
                    put_in(individual_buildable, [:buildable, :reason], checked_reqs)
                    |> put_in([:buildable, :enabled], false)

                  # update acc with disabled buildable
                  Map.update!(acc2, :result_buildables, fn current ->
                    [updated_buildable | current]
                  end)
                end

                # acc2
              end
            end)
          else
            # if there are no buildables of that type
            acc
          end
        end
      )

    all_citizens = results.employed_citizens ++ results.citizens

    # ________________________________________________________________________
    # Iterate through citizens
    # ________________________________________________________________________
    after_citizen_checks =
      Flow.from_enumerable(all_citizens)
      |> Flow.partition()
      |> Flow.reduce(
        fn ->
          %{
            housing_left: results.housing,
            education_left: results.education,
            educated_citizens: %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => []},
            housed_unemployed_citizens: [],
            housed_employed_staying_citizens: [],
            housed_employed_looking_citizens: [],
            unhoused_citizens: all_citizens,
            polluted_citizens: [],
            old_citizens: [],
            reproducing_citizens: []
          }
        end,
        fn citizen, acc ->
          housed_unemployed_citizens =
            if acc.housing_left > 0 && !citizen.has_job && citizen.age < 5000,
              do: [citizen | acc.housed_unemployed_citizens],
              else: acc.housed_unemployed_citizens

          tax_too_high = :rand.uniform() < city.tax_rates[to_string(citizen.education)]

          housed_employed_staying_citizens =
            if acc.housing_left > 0 && citizen.has_job && citizen.age < 5000 && !tax_too_high,
              do: [citizen | acc.housed_employed_staying_citizens],
              else: acc.housed_employed_staying_citizens

          housed_employed_looking_citizens =
            if acc.housing_left > 0 && citizen.has_job && citizen.age < 5000 && tax_too_high,
              do: [citizen | acc.housed_employed_looking_citizens],
              else: acc.housed_employed_looking_citizens

          pollution_death = world.pollution > pollution_ceiling and :rand.uniform() > 0.95

          housing_left =
            if acc.housing_left > 0 and !pollution_death,
              do: acc.housing_left - 1,
              else: acc.housing_left

          unhoused_citizens =
            if acc.housing_left > 0, do: tl(acc.unhoused_citizens), else: acc.unhoused_citizens

          polluted_citizens =
            if pollution_death && citizen.age < 5000,
              do: [citizen | acc.polluted_citizens],
              else: acc.polluted_citizens

          old_citizens =
            if citizen.age > 5000,
              do: [citizen | acc.old_citizens],
              else: acc.old_citizens

          # spawn new citizens if conditions are right; age, random, housing exists
          reproducing_citizens =
            if citizen.age > 500 and citizen.age < 2000 and
                 :rand.uniform(length(city_baked_details.citizens) + 100) == 1,
               do: [citizen | acc.reproducing_citizens],
               else: acc.reproducing_citizens

          will_citizen_learn =
            rem(world.day, 365) == 0 && citizen.education < 5 &&
              acc.education_left[citizen.education + 1] > 0

          education_left =
            if will_citizen_learn do
              Map.update!(acc.education_left, citizen.education + 1, &(&1 - 1))
            else
              acc.education_left
            end

          educated_citizens =
            if will_citizen_learn do
              Map.update!(acc.educated_citizens, citizen.education + 1, &[citizen | &1])
            else
              acc.educated_citizens
            end

          # return
          %{
            housing_left: housing_left,
            education_left: education_left,
            educated_citizens: educated_citizens,
            housed_unemployed_citizens: housed_unemployed_citizens,
            unhoused_citizens: unhoused_citizens,
            housed_employed_staying_citizens: housed_employed_staying_citizens,
            housed_employed_looking_citizens: housed_employed_looking_citizens,
            polluted_citizens: polluted_citizens,
            old_citizens: old_citizens,
            reproducing_citizens: reproducing_citizens
          }
        end
      )
      |> Enum.to_list()
      |> Enum.into(%{})

    city_baked_details
    |> Map.from_struct()
    |> Map.merge(results)
    |> Map.put(:all_citizens, all_citizens)
    |> Map.merge(after_citizen_checks)
  end

  @doc """
  converts %Citizen{} into a human readable string
  """
  def describe_citizen(%Citizens{} = citizen) do
    "#{to_string(citizen.name)} (edu lvl #{citizen.education})"
  end

  @doc """
  moves a given %Citizen{} into a given %Town{}, also takes a `day_moved`
  """
  def move_citizen(
        %Citizens{} = citizen,
        %{} = city_to_move_to,
        day_moved
      ) do
    prev_city = City.get_town!(citizen.town_id)

    if prev_city.id != city_to_move_to.id do
      City.update_log(
        prev_city,
        describe_citizen(citizen) <> " moved to " <> city_to_move_to.title
      )

      City.update_log(
        city_to_move_to,
        describe_citizen(citizen) <> " just moved here from " <> prev_city.title
      )

      City.update_citizens(citizen, %{town_id: city_to_move_to.id, last_moved: day_moved})
    end
  end

  def render_production(production_map, citizen_count) do
    # TODO: add seasonality and region changes to this

    totals = %{
      total_area:
        if(production_map != nil && Map.has_key?(production_map, :area),
          do: production_map.area,
          else: 0
        ),
      total_energy:
        if(production_map != nil and Map.has_key?(production_map, :energy),
          do: production_map.energy,
          else: 0
        ),
      total_housing:
        if(production_map != nil and Map.has_key?(production_map, :housing),
          do: production_map.housing,
          else: 0
        )
    }

    results =
      if production_map != nil && Map.has_key?(production_map, :pollution) &&
           !is_integer(production_map.pollution) do
        Map.replace(production_map, :pollution, production_map.pollution.(citizen_count))
      else
        production_map
      end

    Map.merge(results, totals)
  end

  def kill_citizen(%Citizens{} = citizen, deathReason) do
    City.update_log(
      City.get_town!(citizen.town_id),
      describe_citizen(citizen) <> " has died because of " <> deathReason <> ". RIP"
    )

    City.delete_citizens(citizen)
  end

  @spec find_cities_with_job(list(), integer()) :: list()
  @doc """
  tries to find a cities with matching job level. expects a list of city_calcs and a level to check.
  returns a list of city_calc maps if successful, otherwise nil

  ## Examples
      iex> find_cities_with_job(city_list, 2)
       [%{city: city, workers: #, housing: #, etc}, %{city: city, workers: #, housing: #, etc}]
  """
  def find_cities_with_job(cities, level) do
    Enum.filter(cities, fn city_to_check ->
      is_number(city_to_check.workers[level]) &&
        city_to_check.workers[level] > 0

      # &&
      # city_to_check.housing > 0
    end)
  end

  @doc """
  tries to find city with best match for citizen job based on education level
  takes list of city_calc maps and a %Citizens{} struct
  returns either city_calc map or nil if no results

  ## Examples
      iex> find_best_job(city_list, %Citizens{})
      %{best_city: %{city: %Town{} struct, workers: #, housing: #, tax: #, cost: #, etc}, job_level: level_to_check}
  """
  def find_best_job(cities_to_check, %Citizens{} = citizen) do
    # pseudo code
    # find all cities with workers of best possible job_level
    # then for each city, get:
    # tax_rate for job_level
    # fun rating
    # sprawl rating
    # fun rating
    # pollution rating/health rating
    # then make decision

    # results is a map cities_with_workers and job_level
    results =
      if citizen.education > 0 do
        # [3,2,1,0]
        levels = Enum.reverse(0..citizen.education)

        Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
          cities_with_workers = find_cities_with_job(cities_to_check, level_to_check)

          if List.first(cities_with_workers) == nil,
            do: {:cont, job_acc - 1},
            else: {:halt, %{cities_with_workers: cities_with_workers, job_level: level_to_check}}
        end)
      else
        cities_with_workers = find_cities_with_job(cities_to_check, 0)

        if List.first(cities_with_workers) == nil,
          do: -1,
          else: %{cities_with_workers: cities_with_workers, job_level: 0}
      end

    if is_map(results) do
      scored_results =
        Enum.map(results.cities_with_workers, fn city_calc ->
          # normalize pollution by dividing by energy
          # normalize sprawl by dividing by area
          # should probably do this when calculating it, not here

          pollution_score =
            if city_calc.total_energy <= 0,
              do: 0,
              else: city_calc.pollution / city_calc.total_energy

          area_score =
            if city_calc.total_area <= 0, do: 0, else: city_calc.sprawl / city_calc.total_area

          score =
            city_calc.tax_rates[to_string(results.job_level)] * citizen.preferences["tax_rates"] +
              pollution_score * citizen.preferences["pollution"] +
              area_score * citizen.preferences["sprawl"] +
              citizen.preferences["fun"] * city_calc.fun +
              citizen.preferences["health"] + city_calc.health

          Map.put_new(city_calc, :desirability_score, score)
        end)
        |> Enum.sort(&(&1.desirability_score >= &2.desirability_score))

      if List.first(scored_results) == nil,
        do: nil,
        else: %{best_city: List.first(scored_results), job_level: results.job_level}
    else
      nil
    end
  end

  @doc """
    takes a city_with_stats map, %World, and count of cities in ecosystem

    result here is that city passed in, with additional arrays for citizen info
    ```
    workers: map,
    housing: integer,
    tax: integer,
    money: integer,
    citizens_looking: [],
    citizens_out_of_room: [],
    citizens_too_old: [],
    citizens_polluted: [],
    citizens_to_reproduce: []
    }
    ```
  """
  def calculate_stats_based_on_citizens(city_with_stats, world, cities_count) do
    unless Enum.empty?(city_with_stats.citizens) do
      results =
        Flow.from_enumerable(city_with_stats.citizens)
        |> Flow.partition()
        |> Flow.reduce(
          fn -> city_with_stats end,
          fn citizen, acc ->
            # see if I can just do this all at once instead of a DB write per loop
            # probably can't because it's a unique value per citizen
            # TODO see if

            # set a random pollution ceiling based on how many cities are in the ecosystem
            # could try using :rand.normal here
            # could also use total citizens here

            # if there are NO workers for citizen in this town, returns -1.
            best_possible_job =
              if citizen.education > 0 do
                # look through descending list starting with education level… [3,2,1,0] for example
                levels = Enum.reverse(0..citizen.education)

                Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
                  if acc.workers[level_to_check] > 0,
                    do: {:halt, job_acc},
                    else: {:cont, job_acc - 1}
                end)
              else
                if acc.workers[0] > 0, do: 0, else: -1
              end

            # if education level matches available job, this will be 0, otherwise > 1
            job_gap = citizen.education - best_possible_job

            # if there is an available job, remove it from array
            updated_workers =
              if best_possible_job >= 0,
                do: Map.update!(acc.workers, best_possible_job, &(&1 - 1)),
                else: acc.workers

            # citizen will look if there is a job gap

            citizens_looking =
              if (job_gap > 0 or
                    :rand.uniform() < city_with_stats.tax_rates[to_string(citizen.education)]) and
                   citizen.last_moved + 20 < world.day,
                 do: [citizen | acc.citizens_looking],
                 else: acc.citizens_looking

            citizens_out_of_room =
              if acc.available_housing < 1,
                do: [citizen | acc.citizens_out_of_room],
                else: acc.citizens_out_of_room

            # once a year, update education of citizen if there is capacity
            # e.g. if the edu institutions have capacity
            # otherwise citizens might just keep levelling up
            # oh i guess this is fine, they'll go to a lower job and start looking
            updated_education =
              if rem(world.day, 365) == 0 && citizen.education < 5 &&
                   acc.education[citizen.education + 1] > 0 do
                City.update_citizens(citizen, %{education: min(citizen.education + 1, 5)})

                City.update_log(
                  City.get_town!(citizen.town_id),
                  describe_citizen(citizen) <>
                    " graduated to level " <> to_string(min(citizen.education + 1, 5)) <> "!"
                )

                Map.update!(acc.education, citizen.education + 1, &(&1 - 1))
              else
                acc.education
              end

            # return city

            acc
            |> Map.put(:available_housing, acc.available_housing - 1)
            |> Map.put(:workers, updated_workers)
            |> Map.put(:education, updated_education)
            |> Map.put(:citizens_looking, citizens_looking)
            |> Map.put(:citizens_out_of_room, citizens_out_of_room)
          end
        )
        |> Enum.to_list()
        |> Enum.into(%{})

      results
    else
      # if city has no citizens, just return
      city_with_stats
    end
  end

  @doc """
  takes a %MayorGame.City.Town{} struct

  returns map of available workers by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_workers2(%{} = city) do
    # city_preloaded = preload_city_check(city)
    empty_jobs_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
    # empty_workers_list = [0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0]

    # pseudocode
    # so I have the list of citizens here
    # for each buildable, for each number in its job_amount, check if there is a citizen available
    # wither have to start from the higher levels, or go per citizen

    # want to come out with:
    # buildings enabled/disabled for reason "workers"
    # workers mao is kinda ok to duplicate i think

    # ok, we have the buildabled going in here

    sorted_citizens = Enum.sort(city.citizens, &(&1.education > &2.education))

    results =
      Enum.reduce(
        Buildable.sorted_buildables(),
        %{
          jobs_map: empty_jobs_map,
          city: city,
          tax: 0,
          citizens: sorted_citizens,
          citizens_looking: []
        },
        fn {buildable_type, buildable_options}, acc ->
          # pattern match to pull info out
          buildables_list = Map.get(acc.city.details, buildable_type)
          job_level = buildable_options.job_level

          # ok, they come to here

          # this iterates through the actual list of buildables
          buildable_list_results =
            if length(buildables_list) > 0 do
              # this is where flow could help

              Flow.from_enumerable(buildables_list)
              |> Flow.partition()
              |> Flow.reduce(
                fn ->
                  %{
                    total_workers: 0,
                    available_workers: 0,
                    tax: 0,
                    buildable_list_updated_reasons: [],
                    citizens: acc.citizens,
                    citizens_w_job_gap: acc.citizens_looking
                  }
                end,
                fn individual_buildable, acc3 ->
                  if individual_buildable.buildable.enabled == false do
                    # if disabled, nothing changes
                    # ok we have it here still
                    # oooook maybe i need to add it back to the list here?
                    # %{
                    #   acc3
                    #   | buildable_list_updated_reasons:
                    #       Enum.concat(acc3.buildable_list_updated_reasons, [
                    #         individual_buildable
                    #       ])
                    # }

                    Map.put(
                      acc3,
                      :buildable_list_updated_reasons,
                      Enum.concat(acc3.buildable_list_updated_reasons, [
                        individual_buildable
                      ])
                    )
                    |> Map.put(:tax, 0)
                  else
                    each_job_results =
                      if individual_buildable.metadata.workers_required != nil &&
                           individual_buildable.metadata.workers_required > 0 do
                        Enum.reduce(
                          0..(individual_buildable.metadata.workers_required - 1),
                          %{
                            total_buildable_workers: 0,
                            available_buildable_workers: 0,
                            enabled: true,
                            tax: acc3.tax,
                            citizens: acc3.citizens,
                            citizens_w_job_gap: acc3.citizens_w_job_gap
                          },
                          fn _job_slot, acc4 ->
                            if acc4.citizens !== [] do
                              [top_citizen | tail] = acc4.citizens

                              job_taken =
                                if top_citizen.education < job_level,
                                  do: false,
                                  else: true

                              job_gap_list =
                                if top_citizen.education > job_level do
                                  [top_citizen | acc4.citizens_w_job_gap]
                                else
                                  acc4.citizens_w_job_gap
                                end

                              workers_available =
                                if job_taken,
                                  do: acc4.available_buildable_workers + 1,
                                  else: acc4.available_buildable_workers

                              tax =
                                if job_taken,
                                  do:
                                    round(
                                      (1 + job_level) * 100 *
                                        city.tax_rates[to_string(top_citizen.education)] /
                                        10
                                    ),
                                  else: 0

                              # return
                              %{
                                total_buildable_workers: acc4.total_buildable_workers + 1,
                                available_buildable_workers: workers_available,
                                enabled: if(job_taken, do: true, else: false),
                                tax: acc4.tax + tax,
                                citizens: if(job_taken, do: tail, else: acc4.citizens),
                                citizens_w_job_gap: job_gap_list
                              }
                            else
                              # if no citizens left, return
                              %{
                                total_buildable_workers: acc4.total_buildable_workers + 1,
                                available_buildable_workers: acc4.available_buildable_workers,
                                tax: acc4.tax,
                                enabled: false,
                                citizens: acc4.citizens,
                                citizens_w_job_gap: acc4.citizens_w_job_gap
                              }
                            end
                          end
                        )
                      else
                        %{
                          total_buildable_workers: 0,
                          available_buildable_workers: 0,
                          tax: 0,
                          enabled: true,
                          citizens: acc3.citizens,
                          citizens_w_job_gap: acc3.citizens_w_job_gap
                        }
                      end

                    # HERE I NEED TO ACTUALLY ADD THIS TO THE INDIVIDUAL BUILDABLE
                    updated_buildable =
                      if !each_job_results.enabled do
                        put_reason_in_buildable(
                          acc.city,
                          buildable_type,
                          individual_buildable,
                          "workers"
                        )
                      else
                        individual_buildable
                      end

                    %{
                      total_workers:
                        acc3.total_workers + each_job_results.total_buildable_workers,
                      available_workers:
                        acc3.available_workers + each_job_results.available_buildable_workers,
                      tax: each_job_results.tax,
                      # should only add here
                      buildable_list_updated_reasons:
                        Enum.concat(acc3.buildable_list_updated_reasons, [
                          updated_buildable
                        ]),
                      citizens: each_job_results.citizens,
                      citizens_w_job_gap: each_job_results.citizens_w_job_gap
                    }
                  end
                end
              )
              |> Enum.to_list()
              |> Enum.into(%{})

              # ^end of reduce on buildable_list
            else
              %{
                total_workers: 0,
                available_workers: 0,
                tax: 0,
                buildable_list_updated_reasons: [],
                citizens: acc.citizens,
                citizens_w_job_gap: acc.citizens_looking
              }
            end

          # if there have been updates

          city_update =
            if buildable_list_results.buildable_list_updated_reasons !==
                 Map.get(acc.city.details, buildable_type) do
              put_in(
                acc.city,
                [:details, buildable_type],
                buildable_list_results.buildable_list_updated_reasons
              )
            else
              acc.city
            end

          %{
            jobs_map:
              Map.put(
                acc.jobs_map,
                job_level,
                acc.jobs_map[job_level] + buildable_list_results.total_workers
              ),
            tax: acc.tax + buildable_list_results.tax,
            city: city_update,
            citizens: buildable_list_results.citizens,
            citizens_looking: buildable_list_results.citizens_w_job_gap
          }

          # job_map_results returns this
        end
      )

    # return the adjusted city and other stuff
    results_map = %{
      jobs_map: results.jobs_map,
      tax: results.tax,
      citizens_looking: results.citizens_looking,
      citizens: sorted_citizens
    }

    Map.merge(results.city, results_map)
  end

  @doc """
  takes a %MayorGame.City.Town{} struct and an atom that matches a buildable metadata category

  returns int of total int of that category for the city
  """
  def calculate_total_int(%{} = city, metadata_category) do
    Enum.reduce(
      Buildable.buildables_flat(),
      0,
      fn {buildable_type, buildable_options}, acc ->
        multiplier_key =
          String.to_existing_atom("region_" <> to_string(metadata_category) <> "_multipliers")

        # if it's got the multipliers for this metadata category
        region_multiplier =
          if buildable_options[multiplier_key] !== nil do
            if Map.has_key?(
                 buildable_options[multiplier_key],
                 String.to_existing_atom(city.region)
               ),
               do: buildable_options[multiplier_key][String.to_existing_atom(city.region)],
               else: 1
          else
            1
          end

        buildables = Map.get(city.details, buildable_type)

        if length(buildables) > 0 do
          acc + sum_details_metadata(buildables, metadata_category) * region_multiplier
        else
          acc
        end
      end
    )
  end

  @spec preload_city_check(Town.t()) :: Town.t()
  @doc """
      Take a %Town{}, return the %Town{} with citizens, user, details preloaded
  """
  def preload_city_check(%Town{} = town) do
    if !Ecto.assoc_loaded?(town.details) do
      town |> MayorGame.Repo.preload([:citizens, :user, details: Buildable.buildables_list()])
    else
      town
    end
  end

  @spec bake_details(Details.t()) :: Details.t()
  @doc """
      Takes a %Details{} struct

      returns the %Details{} with each buildable listing %CombinedBuildable{}s instead of raw %Buildable{}s
  """
  def bake_details(%Details{} = details) do
    Enum.reduce(Buildable.buildables_list(), details, fn buildable_list_item,
                                                         details_struct_acc ->
      buildable_count = length(Map.get(details_struct_acc, buildable_list_item))
      has_buildable = Enum.empty?(Map.get(details_struct_acc, buildable_list_item))

      if Map.has_key?(details_struct_acc, buildable_list_item) && !has_buildable do
        buildable_array = Map.get(details_struct_acc, buildable_list_item)

        buildable_metadata = Map.get(Buildable.buildables_flat(), buildable_list_item)

        updated_price = building_price(buildable_metadata.price, buildable_count)

        buildable_metadata_price_updated = %MayorGame.City.BuildableMetadata{
          buildable_metadata
          | price: updated_price
        }

        # I Could add a jobs count here to each buildable

        combined_array =
          Enum.map(buildable_array, fn x ->
            CombinedBuildable.combine_and_apply_upgrades(x, buildable_metadata_price_updated)
          end)

        %{details_struct_acc | buildable_list_item => combined_array}
      else
        details_struct_acc
      end
    end)
  end

  # @spec sum_details_metadata(list(BuildableMetadata.t()), atom) :: integer | float
  @doc """
      takes a list of CombinedBuildables (usually held by details) and returns the sum of the metadata
  """
  def sum_details_metadata(baked_buildable_list, metadata_to_sum) do
    unless Enum.empty?(baked_buildable_list) do
      Enum.reduce(baked_buildable_list, 0, fn x, acc ->
        metadata_value = Map.get(x.metadata, metadata_to_sum)

        unless metadata_value == nil do
          metadata_value + acc
        else
          acc
        end
      end)
    else
      0
    end
  end

  @doc """
   take a city, update the purchasable status of buildables inside
  """
  def bake_city_purchasables(city_with_stats) do
    details_results =
      Enum.reduce(Buildable.buildables_list(), city_with_stats.details, fn b_type,
                                                                           details_struct_acc ->
        # get a list of the buildables
        buildables_array = Map.get(details_struct_acc, b_type)
        # does the details have any of the b_type?
        # d_has_buildable = !Enum.empty?(buildables_array)

        # if Map.has_key?(details_struct_acc, buildable_list_item) && d_has_buildable do
        # b_metadata_baked = Map.get(city_with_stats.details, b_type)

        # bake array of each type of buildable
        baked_array =
          Enum.map(buildables_array, fn combined_buildable ->
            bake_purchasable_status(combined_buildable, city_with_stats)
          end)

        %{details_struct_acc | b_type => baked_array}

        # else
        # details_struct_acc
        # end
      end)

    %{city_with_stats | details: details_results}
  end

  # TODO: clean this shit up
  def bake_purchasable_status(buildable, city_with_stats) do
    if city_with_stats.details.city_treasury > buildable.metadata.price do
      cond do
        # enough energy AND enough area

        buildable.metadata.energy_required != nil and
          city_with_stats.available_energy >= buildable.metadata.energy_required &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area >= buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], true)
          |> put_in([:metadata, :purchasable_reason], "valid")

        # not enough energy, enough area
        buildable.metadata.energy_required != nil and
          city_with_stats.available_energy < buildable.metadata.energy_required &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area >= buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], false)
          |> put_in([:metadata, :purchasable_reason], "not enough energy to build")

        # enough energy, not enough area
        buildable.metadata.energy_required != nil and
          city_with_stats.available_energy >= buildable.metadata.energy_required &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area < buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], false)
          |> put_in([:metadata, :purchasable_reason], "not enough area")

        # not enough energy AND not enough area
        buildable.metadata.energy_required != nil and
          city_with_stats.available_energy < buildable.metadata.energy_required &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area < buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], false)
          |> put_in([:metadata, :purchasable_reason], "not enough area or energy")

        # no energy needed, enough area
        buildable.metadata.energy_required == nil &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area >= buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], true)
          |> put_in([:metadata, :purchasable_reason], "valid")

        # no energy needed, not enough area
        buildable.metadata.energy_required == nil &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area < buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], false)
          |> put_in([:metadata, :purchasable_reason], "not enough area")

        # no area needed, enough energy
        buildable.metadata.area_required == nil &&
            (buildable.metadata.energy_required != nil and
               city_with_stats.available_energy >= buildable.metadata.energy_required) ->
          buildable
          |> put_in([:metadata, :purchasable], true)
          |> put_in([:metadata, :purchasable_reason], "valid")

        # no area needed, not enough energy
        buildable.metadata.area_required == nil &&
            (buildable.metadata.energy_required != nil and
               city_with_stats.available_energy < buildable.metadata.energy_required) ->
          buildable
          |> put_in([:metadata, :purchasable], false)
          |> put_in([:metadata, :purchasable_reason], "not enough energy")

        # no area needed, no energy needed
        buildable.metadata.energy_required == nil and buildable.metadata.area_required == nil ->
          buildable
          |> put_in([:metadata, :purchasable], true)
          |> put_in([:metadata, :purchasable_reason], "valid")

        # catch-all
        true ->
          buildable
          |> put_in([:metadata, :purchasable], true)
          |> put_in([:metadata, :purchasable_reason], "valid")
      end
    else
      buildable
      |> put_in([:metadata, :purchasable], false)
      |> put_in([:metadata, :purchasable_reason], "not enough money")
    end
  end

  def building_price(initial_price, buildable_count) do
    initial_price * round(:math.pow(buildable_count, 2) + 1)
  end

  defp put_reason_in_buildable(_city, _buildable_type, individual_buildable, reason) do
    # City.update_buildable(
    #   city.details,
    #   buildable_type,
    #   individual_buildable.buildable.id,
    #   %{
    #     enabled: false,
    #     # if there's already a reason it's disabled
    #     reason:
    #       cond do
    #         Enum.empty?(individual_buildable.buildable.reason) ->
    #           [reason]

    #         Enum.member?(individual_buildable.buildable.reason, reason) ->
    #           individual_buildable.buildable.reason

    #         true ->
    #           [reason | individual_buildable.buildable.reason]
    #       end
    #   }
    # )

    put_in(individual_buildable, [:buildable, :reason], [
      reason | individual_buildable.buildable.reason
    ])
    |> put_in([:buildable, :enabled], false)
  end

  @doc """
   Returns a list of requirements — empty if all reqs are met, otherwise atoms of reqs not met
  """
  defp check_reqs(%{} = reqs, %{} = checkee) do
    # reqs_minus_workers = Map.drop(reqs, [:workers])

    required_values = Enum.map(reqs, fn {k, v} -> {k, checkee[k] - v} end)

    # get keys of values less than 0
    disabled =
      Enum.flat_map(required_values, fn {k, v} ->
        case v < 0 do
          # transform to integer
          true -> [k]
          # skip the value
          false -> []
        end
      end)

    disabled
  end

  defp check_workers(%{} = reqs, citizens) do
    filtered_citizens = Enum.filter(citizens, fn cit -> cit.education == reqs.workers.level end)

    if length(filtered_citizens) == 0 or hd(filtered_citizens).education < reqs.workers.level do
      []
    else
      count_to_check = min(reqs.workers.count, length(filtered_citizens))

      Enum.reduce_while(0..(count_to_check - 1), [], fn x, acc ->
        cond do
          # Enum.at(citizens, x).education > reqs.workers.level ->
          #   {:cont, [Map.put(Enum.at(citizens, x), :has_job, true) | acc]}

          Enum.at(filtered_citizens, x).education == reqs.workers.level ->
            {:cont, [Enum.at(filtered_citizens, x) | acc]}

          Enum.at(filtered_citizens, x).education < reqs.workers.level ->
            {:halt, acc}

            # true ->
            #   {:cond, acc}
        end
      end)
    end
  end

  defp update_generated_acc(buildable, citizen_count, acc) do
    generated = render_production(buildable.metadata.produces, citizen_count)

    Map.merge(acc, generated, fn k, v1, v2 ->
      recurse_merge(k, v1, v2)
    end)
    |> Map.update!(:result_buildables, fn current ->
      [buildable | current]
    end)
  end

  def recurse_merge(k, v1, v2) do
    if is_number(v1) && is_number(v2) do
      round(v1 + v2)
    else
      Map.merge(v1, v2, fn l, vv1, vv2 ->
        recurse_merge(l, vv1, vv2)
      end)
    end
  end
end
