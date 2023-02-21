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
    # if city.id == 2 && in_dev do
    #   :eprof.start_profiling([self()])
    # end

    city_preloaded = preload_city_check(city)

    city_baked_direct = bake_details_int(city_preloaded, buildables_map)

    all_buildables = city_baked_direct |> Map.take(buildables_map.buildables_list)

    # I think this looks like a keyword list with {type of buildable, list of actual buildables}

    ordered_buildables_not_flat =
      Enum.map(buildables_map.buildables_ordered, fn set_of_buildables ->
        Enum.map(set_of_buildables, fn buildable -> {buildable, all_buildables[buildable]} end)
      end)

    # this probably is pretty heavy for big cities
    # TODO: see if I can get away with keeping this as strings
    # Enum.map(city_baked_direct.citizens_blob, fn citizen ->
    #   for {key, val} <- citizen,
    #       into: %{},
    #       do: {String.to_existing_atom(key), val}
    # end)
    citizens_blob_atoms =
      city_baked_direct.citizens_blob
      |> Enum.map(fn citizen ->
        citizen |> Map.merge(%{"has_job" => false, "town_id" => city.id})
      end)

    # looks good

    # sorted_blob_citizens = Enum.sort_by(citizens_blob_atoms, & &1.education, :desc)

    priorities_atoms =
      for {key, val} <- city_baked_direct.priorities,
          into: %{},
          do: {String.to_existing_atom(key), val}

    citizens_by_level = Enum.group_by(citizens_blob_atoms, & &1["education"])
    citizens_by_level_count = Enum.frequencies_by(citizens_blob_atoms, & &1["education"])

    citizen_count = length(citizens_blob_atoms)

    sorted_buildables = buildables_map.buildables_list |> Enum.sort_by(&priorities_atoms[&1])

    results =
      Enum.reduce(
        sorted_buildables,
        %{
          new_missiles: 0,
          new_shields: 0,
          #
          starting_money: city_baked_direct.treasury,
          starting_steel: city_baked_direct.steel,
          starting_uranium: city_baked_direct.uranium,
          starting_gold: city_baked_direct.gold,
          starting_sulfur: city_baked_direct.sulfur,
          starting_missiles: city_baked_direct.missiles,
          starting_shields: city_baked_direct.shields,
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
          citizens_by_level: citizens_by_level,
          citizens_by_level_count: citizens_by_level_count,
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
          result_buildables: buildables_map.empty_buildable_map
        },
        fn buildable, acc ->
          buildables = all_buildables[buildable]

          # this works
          if buildables == [] do
            acc
          else
            Enum.reduce(buildables, acc, fn individual_buildable, acc2 ->
              # if the building has no requirements
              # if building has requirements
              if individual_buildable.requires == nil do
                # generate final production map
                update_generated_acc(
                  individual_buildable,
                  citizen_count,
                  city.region,
                  season,
                  acc2
                )
                |> Map.update!(:result_buildables, fn current_map ->
                  Map.update(
                    current_map,
                    individual_buildable.title,
                    [individual_buildable],
                    &[individual_buildable | &1]
                  )
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
                    required_worker_count = individual_buildable.requires.workers.count

                    checked_workers =
                      check_workers(
                        individual_buildable.requires.workers.level,
                        acc2.citizens_by_level_count,
                        acc2.citizens_by_level,
                        required_worker_count
                      )

                    # here I gotta subtract the working_levels from acc2.citizens_by_level
                    # and update both in the acc

                    enough_workers =
                      checked_workers.working_count >=
                        individual_buildable.requires.workers.count

                    updated_buildable =
                      if !enough_workers do
                        Map.merge(individual_buildable, %{
                          reason: [:workers],
                          enabled: false,
                          jobs:
                            individual_buildable.requires.workers.count -
                              checked_workers.working_count
                        })
                      else
                        # if all conditions are met
                        individual_buildable
                        |> Map.put(:jobs, 0)
                      end

                    tax_earned =
                      if enough_workers do
                        calculate_earnings(
                          checked_workers.working_count,
                          individual_buildable.requires.workers.level,
                          city.tax_rates[
                            to_string(individual_buildable.requires.workers.level)
                          ]
                        )
                      else
                        0
                      end

                    acc_after_workers =
                      if enough_workers,
                        do:
                          update_generated_acc(
                            updated_buildable,
                            citizen_count,
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

                    # this is wrong
                    workers = checked_workers.working_levels |> Map.values() |> List.flatten()

                    # TODO: do this with a merge so it's less maps in memory
                    acc_after_workers
                    |> Map.update!(:employed_citizens, fn currently_employed ->
                      (workers
                       |> Enum.map(fn cit -> Map.put(cit, "has_job", true) end)) ++
                        currently_employed
                    end)
                    |> Map.put(
                      :citizens_by_level,
                      checked_workers.citizens_by_level
                    )
                    |> Map.put(
                      :citizens_by_level_count,
                      checked_workers.citizens_by_level_count
                    )
                    |> Map.update!(:jobs, fn current_jobs_map ->
                      Map.update!(
                        current_jobs_map,
                        individual_buildable.requires.workers.level,
                        &(&1 + individual_buildable.requires.workers.count -
                            checked_workers.working_count)
                      )
                    end)
                    |> Map.update!(:total_jobs, fn current_total_jobs_map ->
                      Map.update!(
                        current_total_jobs_map,
                        individual_buildable.requires.workers.level,
                        &(&1 + individual_buildable.requires.workers.count)
                      )
                    end)
                    |> Map.update!(:result_buildables, fn current_map ->
                      Map.update(
                        current_map,
                        individual_buildable.title,
                        [updated_buildable],
                        &[updated_buildable | &1]
                      )
                    end)

                    # if number is less than reqs.workers.count, buildable is disabled, reason workers
                    # add jobs equal to workers.count - length

                    # remove citizens from acc2.citizens
                    # add them to acc2.employed_citizens

                    # if it doesn't require workers:
                  else
                    update_generated_acc(
                      individual_buildable,
                      citizen_count,
                      city.region,
                      season,
                      acc2
                    )
                    |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
                    |> Map.update!(:result_buildables, fn current_map ->
                      Map.update(
                        current_map,
                        individual_buildable.title,
                        [individual_buildable],
                        &[individual_buildable | &1]
                      )
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
                  acc2
                  |> Map.update!(:result_buildables, fn current_map ->
                    Map.update(
                      current_map,
                      individual_buildable.title,
                      [updated_buildable],
                      &[updated_buildable | &1]
                    )
                  end)
                end
              end
            end)
          end
        end
      )

    shields_cap = max(city.defense_bases * 100, 50) + city.missile_defense_arrays * 200
    missiles_cap = max(city.air_bases * 100, 50)

    are_shields_capped = results.shields > shields_cap
    are_missiles_capped = results.missiles > missiles_cap

    # optimize this
    results_capped =
      results
      |> cap_shields(shields_cap, are_shields_capped)
      |> cap_missiles(missiles_cap, are_missiles_capped)

    # this is where things get funky

    citizens_left = results.citizens_by_level |> Map.values() |> List.flatten()

    all_citizens = Enum.sort_by(results.employed_citizens ++ citizens_left, & &1["education"], :desc)

    # ________________________________________________________________________
    # Iterate through citizens
    # ________________________________________________________________________
    pollution_reached = world.pollution > pollution_ceiling

    # I don't think this needs to be a reduce. this could me a map then flatten

    # this could be reduce_while there's still housing
    after_citizen_checks =
      all_citizens
      |> Enum.reduce(
        %{
          housing_left: results.housing,
          education_left: results.education,
          educated_citizens: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
          unemployed_citizens: [],
          housed_employed_staying_citizens: [],
          employed_looking_citizens: [],
          unhoused_citizens: [],
          polluted_citizens: [],
          old_citizens: Enum.filter(all_citizens, &(&1["age"] > 3000 * (&1["education"] + 1))),
          reproducing_citizens: 0
        },
        fn citizen, acc ->
          citizen_not_too_old = citizen["age"] < 3000 * (citizen["education"] + 1)

          pollution_death = if(pollution_reached, do: :rand.uniform() > 0.95, else: false)

          tax_too_high =
            :rand.uniform() <
              :math.pow(city.tax_rates[to_string(citizen["education"])], 7 - citizen["education"]) &&
              !pollution_death

          employable = acc.housing_left > 0 && citizen["has_job"] && citizen_not_too_old && !pollution_death

          will_citizen_learn =
            time_to_learn && citizen["education"] < 5 &&
              acc.education_left[citizen["education"] + 1] > 0 && citizen_not_too_old &&
              !pollution_death

          # i can just calculate this globally. doesn't really matter on a per-citizen basis
          will_citizen_reproduce =
            citizen["age"] > 15 and citizen["age"] < 6000 and acc.housing_left > 1 &&
              :rand.uniform(citizen_count) < max(results.health / 100, 5)

          housing_taken = if will_citizen_reproduce, do: 2, else: 1

          updated_citizen =
            citizen
            |> Map.update!(
              "education",
              if(will_citizen_learn,
                do: &(&1 + 1),
                else: & &1
              )
            )
            |> Map.update!("age", &(&1 + 1))

          # TODO
          # do this with merge instead of updates
          merged_acc_map = %{
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
                    updated_citizen["education"],
                    &(&1 - 1)
                  ),
                else: acc.education_left
              ),
            educated_citizens:
              if(will_citizen_learn,
                do:
                  Map.update!(
                    acc.educated_citizens,
                    updated_citizen["education"],
                    &(&1 + 1)
                  ),
                else: acc.educated_citizens
              ),
            unemployed_citizens:
              if(
                acc.housing_left > 0 && !citizen["has_job"] && citizen_not_too_old &&
                  !pollution_death,
                do: [updated_citizen | acc.unemployed_citizens],
                else: acc.unemployed_citizens
              ),
            unhoused_citizens:
              if(
                acc.housing_left <= 0 && citizen_not_too_old && !pollution_death,
                do: [updated_citizen | acc.unhoused_citizens],
                else: acc.unhoused_citizens
              ),
            housed_employed_staying_citizens:
              if(employable && !tax_too_high,
                do: [updated_citizen | acc.housed_employed_staying_citizens],
                else: acc.housed_employed_staying_citizens
              ),
            employed_looking_citizens:
              if(
                employable && tax_too_high &&
                  updated_citizen["last_moved"] < world.day - 10 * updated_citizen["education"],
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

    # if city.id == 2 && in_dev do
    #   :eprof.stop_profiling()
    #   :eprof.analyze()
    # end

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

    prod_map_mult = get_production_map(production_map, multiplier_map, citizen_count, region, season)

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

    results3 =
      if !prod_nil && Map.has_key?(results2, :uranium) &&
           is_function(results2.uranium) do
        Map.replace(results2, :uranium, results2.uranium.(:rand.uniform() > 0.999))
      else
        results2
      end

    if prod_nil do
      totals
    else
      Map.merge(results3, totals)
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

  @doc """
   Returns %{
    citizens_by_level: updated citizens_by_level map,
    working_levels: map of levels to count of workers
  }
  """
  defp check_workers(job_level, citizens_by_level_count, citizens_by_level, required_count) do
    # if there's enough citizens at the correct job level
    results =
      if Map.has_key?(citizens_by_level_count, job_level) &&
           citizens_by_level_count[job_level] >= required_count do
        %{
          citizens_by_level_count: citizens_by_level_count |> Map.update!(job_level, &(&1 - required_count)),
          working_levels: %{job_level => required_count},
          working_count: required_count
        }
      else
        Enum.reduce_while(
          1..required_count,
          %{
            citizens_by_level_count: citizens_by_level_count,
            working_levels: %{},
            working_count: 0
          },
          fn _x, acc ->
            # find top
            best_workable_level =
              Enum.reduce_while(job_level..6, job_level, fn x, _acc2 ->
                if !Map.has_key?(acc.citizens_by_level_count, x) ||
                     acc.citizens_by_level_count[x] < 1,
                   do: {:cont, x + 1},
                   else: {:halt, x}
              end)

            if best_workable_level < 6 do
              updated_acc = %{
                citizens_by_level_count: acc.citizens_by_level_count |> Map.update!(best_workable_level, &(&1 - 1)),
                working_levels:
                  acc.working_levels
                  |> Map.update(
                    best_workable_level,
                    1,
                    &(&1 + 1)
                  ),
                working_count: acc.working_count + 1
              }

              {:cont, updated_acc}
            else
              {:halt, acc}
            end
          end
        )
      end

    working_levels_citizens =
      results.working_levels
      |> Enum.map(fn {level, count} ->
        {level, Enum.take(citizens_by_level[level], count)}
      end)
      |> Enum.into(%{})

    dropped_citizens =
      results.working_levels
      |> Enum.map(fn {level, count} ->
        {level, Enum.drop(citizens_by_level[level], count)}
      end)
      |> Enum.into(%{})

    citizens_by_level_updated = Map.merge(citizens_by_level, dropped_citizens)

    %{
      working_levels: working_levels_citizens,
      citizens_by_level: citizens_by_level_updated,
      citizens_by_level_count: results.citizens_by_level_count,
      working_count: results.working_count
    }
  end

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
    round(worker_count * :math.pow(2, level) * 100 * (tax_rate / 10))
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

  def cap_shields(results_map, cap, true) do
    results_map |> Map.put(:shields, cap) |> Map.put(:new_shields, cap - results_map.shields)
  end

  def cap_shields(results_map, _cap, false) do
    results_map
  end

  def cap_missiles(results_map, cap, true) do
    results_map |> Map.put(:missiles, cap) |> Map.put(:new_missiles, cap - results_map.missiles)
  end

  def cap_missiles(results_map, _cap, false) do
    results_map
  end
end
