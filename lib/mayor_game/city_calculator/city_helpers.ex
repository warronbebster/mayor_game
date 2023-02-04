defmodule MayorGame.CityHelpers do
  alias MayorGame.City.{Citizens, Town, Buildable, Details, CombinedBuildable, World}

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
      housed_unemployed_citizens: [],
      housed_employed_staying_citizens: [],
      housed_employed_looking_citizens: [],
      unhoused_citizens: all_citizens,
      polluted_citizens: [],
      old_citizens: [],
      reproducing_citizens: []
    },
    ```
  """
  def calculate_city_stats(%Town{} = city, %World{} = world, pollution_ceiling) do
    city_preloaded = preload_city_check(city)

    season =
      cond do
        rem(world.day, 365) < 91 -> :winter
        rem(world.day, 365) < 182 -> :spring
        rem(world.day, 365) < 273 -> :summer
        true -> :fall
      end

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
    citizen_count = length(sorted_citizens)

    # buildables_ordered is in order
    results =
      Enum.reduce(
        ordered_buildables,
        %{
          money: city_baked_details.treasury,
          steel: city_baked_details.steel,
          uranium: city_baked_details.uranium,
          gold: city_baked_details.gold,
          sulfur: city_baked_details.sulfur,
          missiles: city_baked_details.missiles,
          loaded_shields: city_baked_details.shields,
          shields: city_baked_details.shields,
          income: 0,
          daily_cost: 0,
          citizen_count: citizen_count,
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
        fn {_buildable_type, buildable_array}, acc ->
          if buildable_array == [] do
            acc
          else
            # for each individual buildable:
            Enum.reduce(buildable_array, acc, fn individual_buildable, acc2 ->
              # if the building has no requirements
              # if building has requirements
              if individual_buildable.metadata.requires == nil do
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
                reqs_minus_workers = Map.drop(individual_buildable.metadata.requires, [:workers])

                checked_reqs = check_reqs(reqs_minus_workers, acc2)

                # if all reqs are met
                if checked_reqs == [] do
                  money_required =
                    if Map.has_key?(individual_buildable.metadata.requires, :money),
                      do: individual_buildable.metadata.requires.money,
                      else: 0

                  # if it requires workers

                  if Map.has_key?(individual_buildable.metadata.requires, :workers) do
                    # here I could just mark that buildable as "enabled pre_workers" or "ready_for_workers" I think?
                    # then loop through jobs outside this loop
                    # could also just look through the jobs not taken outside the loop and check citizens there?

                    checked_workers =
                      check_workers(individual_buildable.metadata.requires, acc2.citizens)

                    enough_workers =
                      length(checked_workers) >=
                        individual_buildable.metadata.requires.workers.count

                    updated_buildable =
                      if !enough_workers do
                        individual_buildable
                        |> put_in([:metadata, :reason], [:workers])
                        |> put_in([:metadata, :enabled], false)
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
                          |> Map.put(:income, acc2.income + tax_earned)
                          |> Map.put(
                            :daily_cost,
                            acc2.daily_cost + money_required
                          )
                          |> Map.put(
                            :money,
                            acc2.money + tax_earned - money_required
                          ),
                        else: acc2

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
                        &(&1 + individual_buildable.metadata.requires.workers.count -
                            length(checked_workers))
                      )
                    end)
                    |> Map.update!(:total_jobs, fn current_total_jobs_map ->
                      Map.update!(
                        current_total_jobs_map,
                        individual_buildable.metadata.requires.workers.level,
                        &(&1 + individual_buildable.metadata.requires.workers.count)
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
                    # if it's operating fine & doesn't require workers

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
                    put_in(individual_buildable, [:metadata, :reason], checked_reqs)
                    |> put_in([:metadata, :enabled], false)

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

    # ————————————————————————————————————————————————————————————————
    # FILL LOWER LEVEL JOBS

    jobs_left = Enum.sum(Map.values(results.jobs))

    citizens_available = Enum.take(results.citizens, jobs_left)

    results_after_2nd_round_jobs =
      if citizens_available == [] do
        results
      else
        # shape: {[list of buildables with jobs], [list of the rest of the buildables]}
        buildables_split_by_jobs =
          Enum.split_with(results.result_buildables, fn y ->
            !is_nil(y.metadata.jobs) && y.metadata.jobs > 0
          end)

        buildables_with_jobs = elem(buildables_split_by_jobs, 0)

        results_updated =
          Enum.reduce(
            buildables_with_jobs,
            %{results: results, citizens_available: citizens_available, buildables_after: []},
            fn buildable, acc ->
              job_level = buildable.metadata.requires.workers.level

              qualified_workers =
                Enum.filter(acc.citizens_available, fn cit -> cit.education >= job_level end)

              newly_employed_workers = Enum.take(qualified_workers, buildable.metadata.jobs)
              enough_workers = length(newly_employed_workers) >= buildable.metadata.jobs

              money_required =
                if Map.has_key?(buildable.metadata.requires, :money),
                  do: buildable.metadata.requires.money,
                  else: 0

              updated_buildable =
                if !enough_workers do
                  buildable
                else
                  # if all conditions are met
                  buildable
                  |> put_in([:metadata, :jobs], 0)
                  |> put_in([:metadata, :reason], [])
                end

              tax_earned =
                round(
                  length(qualified_workers) * (1 + job_level) * 100 *
                    city.tax_rates[to_string(job_level)] / 10
                )

              acc_results =
                if enough_workers,
                  do:
                    update_generated_acc(
                      updated_buildable,
                      citizen_count,
                      city.region,
                      season,
                      acc.results
                    )
                    |> Map.put(:income, acc.results.income + tax_earned)
                    |> Map.put(
                      :daily_cost,
                      acc.results.daily_cost + money_required
                    ),
                  else: acc.results

              %{
                citizens_available: acc.citizens_available -- newly_employed_workers,
                buildables_after: [updated_buildable | acc.buildables_after],
                results:
                  acc_results
                  |> Map.update!(:jobs, fn jobs_map ->
                    Map.update!(jobs_map, job_level, fn v ->
                      v - length(newly_employed_workers)
                    end)
                  end)
              }
            end
          )

        results_updated.results
        |> Map.put(
          :result_buildables,
          elem(buildables_split_by_jobs, 1) ++ results_updated.buildables_after
        )
      end

    all_citizens = results.employed_citizens ++ results.citizens

    # ________________________________________________________________________
    # Iterate through citizens
    # ________________________________________________________________________
    pollution_reached = world.pollution > pollution_ceiling
    time_to_learn = rem(world.day, 365) == 0

    after_citizen_checks =
      all_citizens
      |> Enum.reduce(
        # fn ->
        %{
          housing_left: results_after_2nd_round_jobs.housing,
          education_left: results_after_2nd_round_jobs.education,
          educated_citizens: %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => []},
          housed_unemployed_citizens: [],
          housed_employed_staying_citizens: [],
          housed_employed_looking_citizens: [],
          unhoused_citizens: [],
          polluted_citizens: [],
          old_citizens: Enum.filter(all_citizens, &(&1.age > 10000)),
          reproducing_citizens: []
        },
        # end,

        fn citizen, acc ->
          citizen_not_too_old = citizen.age < 10000

          pollution_death =
            if(pollution_reached, do: pollution_reached and :rand.uniform() > 0.95, else: false)

          tax_too_high =
            :rand.uniform() <
              :math.pow(city.tax_rates[to_string(citizen.education)], 6 - citizen.education) &&
              !pollution_death

          employable =
            acc.housing_left > 0 && citizen.has_job && citizen_not_too_old && !pollution_death

          will_citizen_learn =
            time_to_learn && citizen.education < 5 &&
              acc.education_left[citizen.education + 1] > 0 && citizen_not_too_old &&
              !pollution_death

          acc
          |> Map.update!(
            :housing_left,
            if(acc.housing_left > 0 and !pollution_death, do: &(&1 - 1), else: & &1)
          )
          |> Map.update!(
            :education_left,
            if(will_citizen_learn,
              do: fn current -> Map.update!(current, citizen.education + 1, &(&1 - 1)) end,
              else: & &1
            )
          )
          |> Map.update!(
            :educated_citizens,
            if(will_citizen_learn,
              do: fn current -> Map.update!(current, citizen.education + 1, &[citizen | &1]) end,
              else: & &1
            )
          )
          |> Map.update!(
            :housed_unemployed_citizens,
            if(acc.housing_left > 0 && !citizen.has_job && citizen_not_too_old,
              do: &[citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :unhoused_citizens,
            if(acc.housing_left <= 0 && citizen_not_too_old && !pollution_death,
              do: &[citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :housed_employed_staying_citizens,
            if(employable && !tax_too_high, do: &[citizen | &1], else: & &1)
          )
          |> Map.update!(
            :housed_employed_looking_citizens,
            if(employable && tax_too_high && citizen.last_moved < world.day - 10,
              do: &[citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :polluted_citizens,
            if(pollution_death && citizen_not_too_old, do: &[citizen | &1], else: & &1)
          )
          |> Map.update!(
            :reproducing_citizens,
            if(
              citizen.age > 500 and citizen.age < 2000 and
                :rand.uniform(length(city_baked_details.citizens) + 1) == 1,
              do: &[citizen | &1],
              else: & &1
            )
          )
        end
      )
      |> Enum.into(%{})

    city_baked_details
    |> Map.from_struct()
    |> Map.merge(results_after_2nd_round_jobs)
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
  returns a preference map for citizens
  """
  def create_citizen_preference_map() do
    random_preferences =
      Enum.reduce(Citizens.decision_factors(), %{preference_map: %{}, room_taken: 0}, fn x, acc ->
        value =
          if x == List.last(Citizens.decision_factors()),
            do: (1 - acc.room_taken) |> Float.round(2),
            else: (:rand.uniform() * (1 - acc.room_taken)) |> Float.round(2)

        %{
          preference_map: Map.put(acc.preference_map, to_string(x), value),
          room_taken: acc.room_taken + value
        }
      end)

    random_preferences.preference_map
  end

  def render_production(production_map, multiplier_map, citizen_count, region, season) do
    # TODO: add seasonality and region changes to this
    prod_nil = is_nil(production_map)

    prod_map_mult =
      if is_nil(multiplier_map),
        do: production_map,
        else: production_map |> multiply(multiplier_map, region, season)

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
        )
    }

    results =
      if !prod_nil && Map.has_key?(prod_map_mult, :pollution) &&
           !is_integer(prod_map_mult.pollution) do
        Map.replace(prod_map_mult, :pollution, prod_map_mult.pollution.(citizen_count))
      else
        prod_map_mult
      end

    if prod_nil do
      totals
    else
      Map.merge(results, totals)
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
          if Map.has_key?(multipliers, :season) && Map.has_key?(multipliers.region, k) &&
               Map.has_key?(multipliers.region[k], region),
             do: round(v_x_season * multipliers.region[k]),
             else: v_x_season

        {k, v_x_region}
      end)

    Enum.into(multiplied_map, %{})
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

        # NO FLOW
        combined_array =
          Enum.map(buildable_array, fn x ->
            CombinedBuildable.combine_and_apply_upgrades(x, buildable_metadata_price_updated)
          end)

        # combined_array =
        #   buildable_array
        #   |> Flow.from_enumerable(max_demand: 200)
        #   |> Flow.map(fn x ->
        #     # %CombinedBuildable.combine_and_apply_upgrades(x, buildable_metadata_price_updated)
        #     %CombinedBuildable{
        #       buildable: x,
        #       metadata: buildable_metadata_price_updated
        #     }
        #   end)
        #   |> Enum.to_list()

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

          true ->
            {:cond, acc}
        end
      end)
    end
  end

  @doc """
   Takes (buildable, citizen_count, region, season, acc), returns acc with production rendered
  """
  def update_generated_acc(buildable, citizen_count, region, season, acc) do
    # eventually could optimize this just to run the calc once and then multiply by total enabled buildables

    generated =
      render_production(
        buildable.metadata.produces,
        buildable.metadata.multipliers,
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
end
