defmodule MayorGame.CityHelpers do
  alias MayorGame.City.{Citizens, Town, World}

  @doc """
    takes a %Town{} struct and %World{} struct

    returns a map:
    ```
    %{
      money: city_baked_details.treasury,
      income: 0,
      daily_cost: 0,
      citizens: sorted_citizens,
      citizen_count: int,
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
      housing_left: results.housing,
      education_left: results.education,
      educated_citizens: %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => []},
      unemployed_citizens: [],
      housed_employed_staying_citizens: [],
      employed_looking_citizens: [],
      unhoused_citizens: all_citizens,
      polluted_citizens: [],
      old_citizens: [],
      reproducing_citizens: []
    },
    ```
  """
  def calculate_city_stats(
        %Town{} = city,
        %World{} = world,
        pollution_ceiling,
        season,
        buildables_map,
        in_dev,
        time_to_learn
      ) do
    city_preloaded = preload_city_check(city)

    city_baked_direct = bake_details_int(city_preloaded, buildables_map)

    all_buildables = city_baked_direct |> Map.take(buildables_map.buildables_list)

    # I think this looks like a keyword list with {type of buildable, list of actual buildables}

    ordered_buildables =
      Enum.map(buildables_map.buildables_ordered_flat, fn x -> {x, all_buildables[x]} end)

    ordered_buildables_not_flat =
      Enum.map(buildables_map.buildables_ordered, fn set_of_buildables ->
        Enum.map(set_of_buildables, fn buildable -> {buildable, all_buildables[buildable]} end)
      end)

    citizens_blob_atoms =
      Enum.map(city_baked_direct.citizens_blob, fn citizen ->
        for {key, val} <- citizen,
            into: %{},
            do: {String.to_existing_atom(key), val}
      end)
      |> Enum.map(fn citizen -> citizen |> Map.merge(%{has_job: false, town_id: city.id}) end)

    sorted_blob_citizens = Enum.sort_by(citizens_blob_atoms, & &1.education, :desc)

    citizen_count = length(sorted_blob_citizens)

    # buildables_ordered is in order

    # ordered_buildables is a list of lists:
    # [{_buildable_type, buildable_array}, {_buildable_type, buildable_array}]

    # results =
    #   Enum.reduce(
    #     ordered_buildables,
    #     %{
    #       new_money: 0,
    #       new_steel: 0,
    #       new_uranium: 0,
    #       new_gold: 0,
    #       new_sulfur: 0,
    #       new_missiles: 0,
    #       new_shields: 0,
    #       #
    #       money: city_baked_direct.treasury,
    #       steel: city_baked_direct.steel,
    #       uranium: city_baked_direct.uranium,
    #       gold: city_baked_direct.gold,
    #       sulfur: city_baked_direct.sulfur,
    #       missiles: city_baked_direct.missiles,
    #       shields: city_baked_direct.shields,
    #       #
    #       income: 0,
    #       daily_cost: 0,
    #       citizen_count: citizen_count,
    #       citizens: sorted_blob_citizens,
    #       employed_citizens: [],
    #       fun: 0,
    #       health: 0,
    #       sprawl: 0,
    #       total_housing: 0,
    #       housing: 0,
    #       total_energy: 0,
    #       energy: 0,
    #       pollution: 0,
    #       jobs: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
    #       total_jobs: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
    #       education: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
    #       total_area: 0,
    #       area: 0,
    #       buildables: ordered_buildables,
    #       result_buildables: []
    #     },
    #     fn {_buildable_type, buildable_array}, acc ->
    #       if buildable_array == [] do
    #         acc
    #       else
    #         # for each individual buildable:
    #         Enum.reduce(buildable_array, acc, fn individual_buildable, acc2 ->
    #           # if the building has no requirements
    #           # if building has requirements
    #           if individual_buildable.requires == nil do
    #             # generate final production map
    #             update_generated_acc(
    #               individual_buildable,
    #               length(acc.citizens),
    #               city.region,
    #               season,
    #               acc2
    #             )
    #             |> Map.update!(:result_buildables, fn current ->
    #               [individual_buildable | current]
    #             end)
    #           else
    #             reqs_minus_workers = Map.drop(individual_buildable.requires, [:workers])

    #             checked_reqs = check_reqs(reqs_minus_workers, acc2)

    #             # if all reqs are met
    #             if checked_reqs == [] do
    #               money_required =
    #                 if Map.has_key?(individual_buildable.requires, :money),
    #                   do: individual_buildable.requires.money,
    #                   else: 0

    #               # if it requires workers

    #               if Map.has_key?(individual_buildable.requires, :workers) do
    #                 # here I could just mark that buildable as "enabled pre_workers" or "ready_for_workers" I think?
    #                 # then loop through jobs outside this loop
    #                 # could also just look through the jobs not taken outside the loop and check citizens there?
    #                 required_worker_count =
    #                   if is_nil(individual_buildable.jobs) do
    #                     individual_buildable.requires.workers.count
    #                   else
    #                     individual_buildable.jobs
    #                   end

    #                 checked_workers =
    #                   check_workers(
    #                     individual_buildable.requires,
    #                     acc2.citizens,
    #                     required_worker_count,
    #                     3
    #                   )

    #                 working_workers = length(checked_workers)

    #                 enough_workers =
    #                   working_workers >=
    #                     individual_buildable.requires.workers.count

    #                 updated_buildable =
    #                   if !enough_workers do
    #                     Map.merge(individual_buildable, %{
    #                       reason: [:workers],
    #                       enabled: false,
    #                       jobs: individual_buildable.requires.workers.count - working_workers
    #                     })
    #                   else
    #                     # if all conditions are met
    #                     individual_buildable
    #                     |> Map.put(:jobs, 0)
    #                   end

    #                 tax_earned =
    #                   calculate_earnings(
    #                     working_workers,
    #                     individual_buildable.requires.workers.level,
    #                     city.tax_rates[
    #                       to_string(individual_buildable.requires.workers.level)
    #                     ]
    #                   )

    #                 acc_after_workers =
    #                   if enough_workers,
    #                     do:
    #                       update_generated_acc(
    #                         updated_buildable,
    #                         length(acc.citizens),
    #                         city.region,
    #                         season,
    #                         acc2
    #                       )
    #                       |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
    #                       |> Map.merge(%{
    #                         income: acc2.income + tax_earned,
    #                         daily_cost: acc2.daily_cost + money_required,
    #                         money: acc2.money + tax_earned - money_required
    #                       }),
    #                     else: acc2

    #                 # update acc with disabled buildable

    #                 workers_right_level =
    #                   Enum.filter(checked_workers, fn cit ->
    #                     cit.education == individual_buildable.requires.workers.level
    #                   end)

    #                 acc_after_workers
    #                 |> Map.update!(:employed_citizens, fn currently_employed ->
    #                   Enum.map(workers_right_level, fn cit ->
    #                     Map.put(cit, :has_job, true)
    #                   end) ++
    #                     currently_employed
    #                 end)
    #                 |> Map.update!(:citizens, fn current_citizens ->
    #                   # this is where I need to filter by the job level
    #                   # I thought this would do it
    #                   # TODO: OPTIMIZE THIS
    #                   current_citizens -- checked_workers
    #                 end)
    #                 |> Map.update!(:jobs, fn current_jobs_map ->
    #                   Map.update!(
    #                     current_jobs_map,
    #                     individual_buildable.requires.workers.level,
    #                     &(&1 + individual_buildable.requires.workers.count -
    #                         length(checked_workers))
    #                   )
    #                 end)
    #                 |> Map.update!(:total_jobs, fn current_total_jobs_map ->
    #                   Map.update!(
    #                     current_total_jobs_map,
    #                     individual_buildable.requires.workers.level,
    #                     &(&1 + individual_buildable.requires.workers.count)
    #                   )
    #                 end)
    #                 |> Map.update!(:result_buildables, fn current ->
    #                   [updated_buildable | current]
    #                 end)

    #                 # if number is less than reqs.workers.count, buildable is disabled, reason workers
    #                 # add jobs equal to workers.count - length

    #                 # remove citizens from acc2.citizens
    #                 # add them to acc2.employed_citizens
    #               else
    #                 update_generated_acc(
    #                   individual_buildable,
    #                   length(acc.citizens),
    #                   city.region,
    #                   season,
    #                   acc2
    #                 )
    #                 |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
    #                 |> Map.update!(:result_buildables, fn current ->
    #                   [individual_buildable | current]
    #                 end)
    #                 |> Map.put(
    #                   :daily_cost,
    #                   acc2.daily_cost + money_required
    #                 )
    #               end
    #             else
    #               # if requirements not met
    #               updated_buildable =
    #                 individual_buildable
    #                 |> Map.merge(%{
    #                   reason: checked_reqs,
    #                   enabled: false
    #                 })

    #               # update acc with disabled buildable
    #               Map.update!(acc2, :result_buildables, fn current ->
    #                 [updated_buildable | current]
    #               end)
    #             end
    #           end
    #         end)
    #       end
    #     end
    #   )

    results =
      Enum.reduce(
        ordered_buildables_not_flat,
        %{
          new_money: 0,
          new_steel: 0,
          new_uranium: 0,
          new_gold: 0,
          new_sulfur: 0,
          new_missiles: 0,
          new_shields: 0,
          #
          money: city_baked_direct.treasury,
          steel: city_baked_direct.steel,
          uranium: city_baked_direct.uranium,
          gold: city_baked_direct.gold,
          sulfur: city_baked_direct.sulfur,
          missiles: city_baked_direct.missiles,
          shields: city_baked_direct.shields,
          #
          income: 0,
          daily_cost: 0,
          citizen_count: citizen_count,
          citizens: sorted_blob_citizens,
          employed_citizens: [],
          fun: 0,
          health: 0,
          sprawl: 0,
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
        fn list_of_buildables, acc ->
          buildable_lists = Keyword.values(list_of_buildables)

          longest_list =
            if buildable_lists != [] do
              length(Enum.max_by(buildable_lists, &length(&1)))
            else
              0
            end

          filled_lists =
            Enum.map(buildable_lists, fn list ->
              length_gap = longest_list - length(list)

              if length_gap == 0 do
                list
              else
                filler_list = for _ <- 1..length_gap, do: nil
                list ++ filler_list
              end
            end)

          flattened =
            filled_lists
            |> Enum.zip()
            |> Enum.map(&Tuple.to_list(&1))
            |> List.flatten()
            |> Enum.filter(&(!is_nil(&1)))

          # this works
          if flattened == [] do
            acc
          else
            Enum.reduce(flattened, acc, fn individual_buildable, acc2 ->
              # if the building has no requirements
              # if building has requirements
              if individual_buildable.requires == nil do
                # generate final production map
                update_generated_acc(
                  individual_buildable,
                  length(acc.citizens),
                  city.region,
                  season,
                  acc2
                )
                |> Map.update!(:result_buildables, fn current ->
                  [individual_buildable | current]
                end)
              else
                reqs_minus_workers = Map.drop(individual_buildable.requires, [:workers])

                checked_reqs = check_reqs(reqs_minus_workers, acc2)

                # if all reqs are met
                if checked_reqs == [] do
                  money_required =
                    if Map.has_key?(individual_buildable.requires, :money),
                      do: individual_buildable.requires.money,
                      else: 0

                  # if it requires workers

                  if Map.has_key?(individual_buildable.requires, :workers) do
                    # here I could just mark that buildable as "enabled pre_workers" or "ready_for_workers" I think?
                    # then loop through jobs outside this loop
                    # could also just look through the jobs not taken outside the loop and check citizens there?
                    required_worker_count =
                      if is_nil(individual_buildable.jobs) do
                        individual_buildable.requires.workers.count
                      else
                        individual_buildable.jobs
                      end

                    checked_workers =
                      check_workers(
                        individual_buildable.requires,
                        acc2.citizens,
                        required_worker_count,
                        3
                      )

                    working_workers = length(checked_workers)

                    enough_workers =
                      working_workers >=
                        individual_buildable.requires.workers.count

                    updated_buildable =
                      if !enough_workers do
                        Map.merge(individual_buildable, %{
                          reason: [:workers],
                          enabled: false,
                          jobs: individual_buildable.requires.workers.count - working_workers
                        })
                      else
                        # if all conditions are met
                        individual_buildable
                        |> Map.put(:jobs, 0)
                      end

                    tax_earned =
                      calculate_earnings(
                        working_workers,
                        individual_buildable.requires.workers.level,
                        city.tax_rates[
                          to_string(individual_buildable.requires.workers.level)
                        ]
                      )

                    acc_after_workers =
                      if enough_workers,
                        do:
                          update_generated_acc(
                            updated_buildable,
                            length(acc.citizens),
                            city.region,
                            season,
                            acc2
                          )
                          |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
                          |> Map.merge(%{
                            income: acc2.income + tax_earned,
                            daily_cost: acc2.daily_cost + money_required,
                            money: acc2.money + tax_earned - money_required
                          }),
                        else: acc2

                    # update acc with disabled buildable

                    workers_right_level =
                      Enum.filter(checked_workers, fn cit ->
                        cit.education == individual_buildable.requires.workers.level
                      end)

                    acc_after_workers
                    |> Map.update!(:employed_citizens, fn currently_employed ->
                      Enum.map(workers_right_level, fn cit ->
                        Map.put(cit, :has_job, true)
                      end) ++
                        currently_employed
                    end)
                    |> Map.update!(:citizens, fn current_citizens ->
                      # this is where I need to filter by the job level
                      # I thought this would do it
                      # TODO: OPTIMIZE THIS
                      current_citizens -- checked_workers
                    end)
                    |> Map.update!(:jobs, fn current_jobs_map ->
                      Map.update!(
                        current_jobs_map,
                        individual_buildable.requires.workers.level,
                        &(&1 + individual_buildable.requires.workers.count -
                            length(checked_workers))
                      )
                    end)
                    |> Map.update!(:total_jobs, fn current_total_jobs_map ->
                      Map.update!(
                        current_total_jobs_map,
                        individual_buildable.requires.workers.level,
                        &(&1 + individual_buildable.requires.workers.count)
                      )
                    end)
                    |> Map.update!(:result_buildables, fn current ->
                      [updated_buildable | current]
                    end)

                    # if number is less than reqs.workers.count, buildable is disabled, reason workers
                    # add jobs equal to workers.count - length

                    # remove citizens from acc2.citizens
                    # add them to acc2.employed_citizens
                  else
                    update_generated_acc(
                      individual_buildable,
                      length(acc.citizens),
                      city.region,
                      season,
                      acc2
                    )
                    |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
                    |> Map.update!(:result_buildables, fn current ->
                      [individual_buildable | current]
                    end)
                    |> Map.put(
                      :daily_cost,
                      acc2.daily_cost + money_required
                    )
                  end
                else
                  # if requirements not met
                  updated_buildable =
                    individual_buildable
                    |> Map.merge(%{
                      reason: checked_reqs,
                      enabled: false
                    })

                  # update acc with disabled buildable
                  Map.update!(acc2, :result_buildables, fn current ->
                    [updated_buildable | current]
                  end)
                end
              end
            end)
          end
        end
      )

    shields_cap = max(city.defense_bases * 1000, 100)

    shields_capped = results.shields > shields_cap

    results_capped =
      if shields_capped do
        results |> Map.put(:shields, shields_cap) |> Map.put(:new_shields, 0)
      else
        results
      end

    all_citizens =
      Enum.sort_by(results.employed_citizens ++ results.citizens, & &1.education, :desc)

    # ________________________________________________________________________
    # Iterate through citizens
    # ________________________________________________________________________
    pollution_reached = world.pollution > pollution_ceiling

    # I don't think this needs to be a reduce. this could me a map then flatten

    after_citizen_checks =
      all_citizens
      |> Enum.reduce(
        %{
          all_citizens_persisting: [],
          housing_left: results.housing,
          education_left: results.education,
          educated_citizens: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
          unemployed_citizens: [],
          housed_employed_staying_citizens: [],
          employed_looking_citizens: [],
          unhoused_citizens: [],
          polluted_citizens: [],
          old_citizens: Enum.filter(all_citizens, &(&1.age > 3000 * (&1.education + 1))),
          reproducing_citizens: 0
        },
        fn citizen, acc ->
          citizen_not_too_old = citizen.age < 3000 * (citizen.education + 1)

          pollution_death =
            if(pollution_reached, do: pollution_reached and :rand.uniform() > 0.95, else: false)

          tax_too_high =
            :rand.uniform() <
              :math.pow(city.tax_rates[to_string(citizen.education)], 7 - citizen.education) &&
              !pollution_death

          employable =
            acc.housing_left > 0 && citizen.has_job && citizen_not_too_old && !pollution_death

          will_citizen_learn =
            time_to_learn && citizen.education < 5 &&
              acc.education_left[citizen.education + 1] > 0 && citizen_not_too_old &&
              !pollution_death

          will_citizen_reproduce =
            citizen.age > 500 and citizen.age < 3000 and acc.housing_left > 1 &&
              :rand.uniform(min(citizen_count, 5000)) < max(results.health / 100, 5)

          housing_taken = if will_citizen_reproduce, do: 2, else: 1

          updated_citizen =
            citizen
            |> Map.update!(
              :education,
              if(will_citizen_learn,
                do: &(&1 + 1),
                else: & &1
              )
            )
            |> Map.update!(:age, &(&1 + 1))

          # TODO
          # do this with merge instead of updates
          merged_acc_map = %{
            all_citizens_persisting:
              if(!pollution_death && citizen_not_too_old,
                do: [updated_citizen | acc.all_citizens_persisting],
                else: acc.all_citizens_persisting
              ),
            housing_left:
              if(acc.housing_left > 0 and !pollution_death and citizen_not_too_old,
                do: acc.housing_left - housing_taken,
                else: acc.housing_left
              ),
            education_left:
              if(will_citizen_learn,
                do:
                  Map.update!(
                    acc.education_left,
                    updated_citizen.education,
                    &(&1 - 1)
                  ),
                else: acc.education_left
              ),
            educated_citizens:
              if(will_citizen_learn,
                do:
                  Map.update!(
                    acc.educated_citizens,
                    updated_citizen.education,
                    &(&1 + 1)
                  ),
                else: acc.educated_citizens
              ),
            unemployed_citizens:
              if(
                acc.housing_left > 0 && !citizen.has_job && citizen_not_too_old &&
                  !pollution_death,
                do: [updated_citizen | acc.unemployed_citizens],
                else: acc.unemployed_citizens
              ),
            housed_employed_staying_citizens:
              if(employable && !tax_too_high,
                do: [updated_citizen | acc.housed_employed_staying_citizens],
                else: acc.housed_employed_staying_citizens
              ),
            employed_looking_citizens:
              if(
                employable && tax_too_high &&
                  updated_citizen.last_moved < world.day - 10 * updated_citizen.education,
                do: [updated_citizen | acc.employed_looking_citizens],
                else: acc.employed_looking_citizens
              ),
            polluted_citizens:
              if(pollution_death && citizen_not_too_old,
                do: [updated_citizen | acc.polluted_citizens],
                else: acc.polluted_citizens
              ),
            reproducing_citizens:
              if(will_citizen_reproduce,
                do: acc.reproducing_citizens + 1,
                else: acc.reproducing_citizens
              )
          }

          Map.merge(acc, merged_acc_map)
        end
      )
      |> Enum.into(%{})

    city_baked_direct
    |> Map.from_struct()
    |> Map.merge(results_capped)
    |> Map.put(:all_citizens, all_citizens)
    |> Map.merge(after_citizen_checks)
  end

  @doc """
  converts %Citizen{} into a human readable string
  """

  # def describe_citizen(%Citizens{} = citizen) do
  #   "#{to_string(citizen.name)} (edu lvl #{citizen.education})"
  # end

  def get_production_map(production_map, multiplier_map, citizen_count, region, season) do
    # this is fetched by web live and server-side calculations
    if is_nil(multiplier_map),
      do: production_map,
      else: production_map |> multiply(multiplier_map, region, season)
  end

  def render_production(production_map, multiplier_map, citizen_count, region, season) do
    # TODO: add seasonality and region changes to this
    prod_nil = is_nil(production_map)

    prod_map_mult =
      get_production_map(production_map, multiplier_map, citizen_count, region, season)

    totals = %{
      total_area:
        if(!prod_nil && Map.has_key?(prod_map_mult, :area),
          do: prod_map_mult.area,
          else: 0
        ),
      total_energy:
        if(!prod_nil and Map.has_key?(prod_map_mult, :energy),
          do: prod_map_mult.energy,
          else: 0
        ),
      total_housing:
        if(!prod_nil and Map.has_key?(prod_map_mult, :housing),
          do: prod_map_mult.housing,
          else: 0
        ),
      new_shields:
        if(!prod_nil and Map.has_key?(prod_map_mult, :shields),
          do: prod_map_mult.shields,
          else: 0
        ),
      new_missiles:
        if(!prod_nil and Map.has_key?(prod_map_mult, :missiles),
          do: prod_map_mult.missiles,
          else: 0
        ),
      new_gold:
        if(!prod_nil and Map.has_key?(prod_map_mult, :gold),
          do: prod_map_mult.gold,
          else: 0
        ),
      new_steel:
        if(!prod_nil and Map.has_key?(prod_map_mult, :steel),
          do: prod_map_mult.steel,
          else: 0
        ),
      new_uranium:
        if(!prod_nil and Map.has_key?(prod_map_mult, :uranium),
          do: prod_map_mult.uranium,
          else: 0
        ),
      new_sulfur:
        if(!prod_nil and Map.has_key?(prod_map_mult, :sulfur),
          do: prod_map_mult.sulfur,
          else: 0
        )
    }

    results =
      if !prod_nil && Map.has_key?(prod_map_mult, :pollution) &&
           !is_integer(prod_map_mult.pollution) do
        Map.replace(prod_map_mult, :pollution, prod_map_mult.pollution.(citizen_count))
      else
        prod_map_mult
      end

    edu_luck = if :rand.uniform() > 0.95, do: 1, else: 0

    results2 =
      if !prod_nil && Map.has_key?(results, :education) &&
           is_function(results.education) do
        Map.replace(results, :education, results.education.(:rand.uniform(5), edu_luck))
      else
        results
      end

    if prod_nil do
      totals
    else
      Map.merge(results2, totals)
    end
  end

  def multiply(production_map, multipliers, region, season) do
    multiplied_map =
      Enum.map(production_map, fn {k, v} ->
        v_x_season =
          if Map.has_key?(multipliers, :season) && Map.has_key?(multipliers.season, k) &&
               Map.has_key?(multipliers.season[k], season),
             do: v * multipliers.season[k][season],
             else: v

        v_x_region =
          if Map.has_key?(multipliers, :region) && Map.has_key?(multipliers.region, k) &&
               Map.has_key?(multipliers.region[k], region),
             do: round(v_x_season * multipliers.region[k]),
             else: v_x_season

        {k, v_x_region}
      end)

    Enum.into(multiplied_map, %{})
  end

  @spec preload_city_check(Town.t()) :: Town.t()
  @doc """
      Take a %Town{}, return the %Town{} with citizens, user preloaded
  """
  def preload_city_check(%Town{} = town) do
    if !Ecto.assoc_loaded?(town.user) do
      town |> MayorGame.Repo.preload([:user])
    else
      town
    end
  end

  # @spec bake_details_int(Town.t(), %{}) :: Town.t()
  @doc """
      Takes a %Town{} struct

      returns the %Details{} with each buildable listing %CombinedBuildable{}s instead of raw %Buildable{}s
  """
  def bake_details_int(%Town{} = town, buildables_map) do
    updated_map =
      Enum.map(buildables_map.buildables_list, fn buildable_list_item ->
        buildable_count = Map.get(town, buildable_list_item)
        buildable_metadata = Map.get(buildables_map.buildables_flat, buildable_list_item)

        combined_array =
          if buildable_count <= 0 do
            []
          else
            Enum.map(1..buildable_count, fn _x ->
              buildable_metadata
            end)
          end

        {buildable_list_item, combined_array}
      end)
      |> Map.new()

    Map.merge(town, updated_map)
  end

  def building_price(initial_price, buildable_count) do
    initial_price * round(:math.pow(buildable_count, 2) + 1)
  end

  @doc """
   Returns a list of requirements — empty if all reqs are met, otherwise atoms of reqs not met
  """
  def check_reqs(%{} = reqs, %{} = checkee) do
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

  defp check_workers(%{} = reqs, citizens, required_count, education_diff) do
    Enum.filter(citizens, fn cit ->
      cit.education >= reqs.workers.level && cit.education <= reqs.workers.level + education_diff
    end)
    |> Enum.take(-required_count)
  end

  #

  # defp activation_rounds_recursive(result_blob, buildables, city, season, education_diff) do
  #   count = result_blob.updated_buildable_count
  #   result_blob = activation_round(result_blob, buildables, city, season, education_diff)

  #   # enforce up to the full range of education level differences is considered, to prevent recursion from stopping early
  #   if result_blob.updated_buildable_count > count || education_diff < 5 do
  #     # filter buildables for the next round of checks
  #     buildables_split_by_jobs =
  #       Enum.split_with(result_blob.result_buildables, fn y ->
  #         !y.enabled && (is_nil(y.jobs) || y.jobs > 0)
  #       end)

  #     result_blob_input =
  #       result_blob |> Map.put(:result_buildables, elem(buildables_split_by_jobs, 1))

  #     activation_rounds_recursive(
  #       result_blob_input,
  #       elem(buildables_split_by_jobs, 0),
  #       city,
  #       season,
  #       education_diff + 1
  #     )
  #   else
  #     result_blob
  #   end
  # end

  # defp activation_round(result_blob, buildables, city, season, education_diff) do
  #   Enum.reduce(
  #     buildables,
  #     result_blob,
  #     fn individual_buildable, acc ->
  #       # if the building has no requirements
  #       # if building has requirements
  #       if individual_buildable.requires == nil do
  #         updated_buildable =
  #           individual_buildable
  #           |> Map.merge(%{
  #             reason: [],
  #             enabled: true,
  #             jobs: 0
  #           })

  #         # generate final production map
  #         update_generated_acc(
  #           updated_buildable,
  #           length(acc.citizens),
  #           city.region,
  #           season,
  #           acc
  #         )
  #         |> Map.update!(:result_buildables, fn current ->
  #           [updated_buildable | current]
  #         end)
  #       else
  #         reqs_minus_workers = Map.drop(individual_buildable.requires, [:workers])
  #         checked_reqs = check_reqs(reqs_minus_workers, acc)

  #         # if all reqs are met
  #         if checked_reqs == [] do
  #           money_required =
  #             if Map.has_key?(individual_buildable.requires, :money),
  #               do: individual_buildable.requires.money,
  #               else: 0

  #           # if it requires workers

  #           if Map.has_key?(individual_buildable.requires, :workers) &&
  #                individual_buildable.jobs != 0 do
  #             # here I could just mark that buildable as "enabled pre_workers" or "ready_for_workers" I think?
  #             # then loop through jobs outside this loop
  #             # could also just look through the jobs not taken outside the loop and check citizens there?

  #             required_worker_count =
  #               if individual_buildable.jobs == nil do
  #                 individual_buildable.requires.workers.count
  #               else
  #                 individual_buildable.jobs
  #               end

  #             checked_workers =
  #               check_workers(
  #                 individual_buildable.requires,
  #                 acc.citizens,
  #                 required_worker_count,
  #                 education_diff
  #               )

  #             checked_workers_count = length(checked_workers)

  #             enough_workers = checked_workers_count >= required_worker_count

  #             updated_buildable =
  #               if !enough_workers do
  #                 individual_buildable
  #                 |> Map.merge(%{
  #                   reason: [:workers],
  #                   enabled: false,
  #                   jobs: required_worker_count - checked_workers_count
  #                 })
  #               else
  #                 # if all conditions are met
  #                 individual_buildable
  #                 |> Map.merge(%{
  #                   reason: [],
  #                   enabled: true,
  #                   jobs: 0
  #                 })
  #               end

  #             tax_earned =
  #               calculate_earnings(
  #                 checked_workers_count,
  #                 individual_buildable.requires.workers.level,
  #                 city.tax_rates[
  #                   to_string(individual_buildable.requires.workers.level)
  #                 ]
  #               )

  #             acc_after_workers =
  #               if enough_workers,
  #                 do:
  #                   update_generated_acc(
  #                     updated_buildable,
  #                     length(acc.citizens),
  #                     city.region,
  #                     season,
  #                     acc
  #                   )
  #                   |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
  #                   |> Map.merge(%{
  #                     income: acc.income + tax_earned,
  #                     daily_cost: acc.daily_cost + money_required,
  #                     money: acc.money + tax_earned - money_required,
  #                     updated_buildable_count: acc.updated_buildable_count + 1
  #                   }),
  #                 else: acc

  #             # update acc with disabled buildable

  #             acc_after_workers
  #             |> Map.update!(:employed_citizens, fn currently_employed ->
  #               Enum.map(checked_workers, fn cit -> Map.put(cit, :has_job, true) end) ++
  #                 currently_employed
  #             end)
  #             |> Map.update!(:citizens, fn current_citizens ->
  #               # this is where I need to filter by the job level
  #               # I thought this would do it
  #               # TODO: OPTIMIZE THIS
  #               current_citizens -- checked_workers
  #             end)
  #             |> Map.update!(:jobs, fn current_jobs_map ->
  #               Map.update!(
  #                 current_jobs_map,
  #                 individual_buildable.requires.workers.level,
  #                 &(&1 +
  #                     if is_nil(individual_buildable.jobs) do
  #                       required_worker_count
  #                     else
  #                       0
  #                     end - checked_workers_count)
  #               )
  #             end)
  #             |> Map.update!(:total_jobs, fn current_total_jobs_map ->
  #               Map.update!(
  #                 current_total_jobs_map,
  #                 individual_buildable.requires.workers.level,
  #                 &(&1 +
  #                     if is_nil(individual_buildable.jobs) do
  #                       required_worker_count
  #                     else
  #                       0
  #                     end)
  #               )
  #             end)
  #             |> Map.update!(:result_buildables, fn current ->
  #               [updated_buildable | current]
  #             end)

  #             # if number is less than reqs.workers.count, buildable is disabled, reason workers
  #             # add jobs equal to workers.count - length

  #             # remove citizens from acc.citizens
  #             # add them to acc.employed_citizens
  #           else
  #             # if it's operating fine & doesn't require workers
  #             updated_buildable =
  #               individual_buildable
  #               |> Map.merge(%{
  #                 reason: [],
  #                 enabled: true,
  #                 jobs: 0
  #               })

  #             update_generated_acc(
  #               updated_buildable,
  #               length(acc.citizens),
  #               city.region,
  #               season,
  #               acc
  #             )
  #             |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
  #             |> Map.update!(:result_buildables, fn current ->
  #               [updated_buildable | current]
  #             end)
  #             |> Map.merge(%{
  #               daily_cost: acc.daily_cost + money_required,
  #               updated_buildable_count: acc.updated_buildable_count + 1
  #             })
  #           end
  #         else
  #           # if requirements not met
  #           updated_buildable =
  #             individual_buildable
  #             |> Map.merge(%{
  #               reason: checked_reqs,
  #               enabled: false
  #             })

  #           # update acc with disabled buildable
  #           Map.update!(acc, :result_buildables, fn current ->
  #             [updated_buildable | current]
  #           end)
  #         end
  #       end
  #     end
  #   )
  # end

  @doc """
   Takes (buildable, citizen_count, region, season, acc), returns acc with production rendered
  """
  def update_generated_acc(buildable, citizen_count, region, season, acc) do
    # eventually could optimize this just to run the calc once and then multiply by total enabled buildables

    generated =
      render_production(
        buildable.produces,
        buildable.multipliers,
        citizen_count,
        region,
        season
      )

    Map.merge(acc, generated, fn k, v1, v2 ->
      recurse_merge(k, v1, v2)
    end)
  end

  def recurse_merge(_k, v1, v2) do
    if is_number(v1) && is_number(v2) do
      round(v1 + v2)
    else
      Map.merge(v1, v2, fn l, vv1, vv2 ->
        recurse_merge(l, vv1, vv2)
      end)
    end
  end

  def calculate_earnings(worker_count, level, tax_rate) do
    round(worker_count * :math.pow(1.5, level + 1) * 100 * (tax_rate / 10))
  end

  def atomize_keys(map) do
    Map.new(map, fn {k, v} ->
      {if(!is_atom(k), do: String.to_existing_atom(k), else: k), v}
    end)
  end

  def integerize_keys(map) do
    Map.new(map, fn {k, v} ->
      {if(!is_integer(k), do: String.to_integer(k), else: k), v}
    end)
  end
end
