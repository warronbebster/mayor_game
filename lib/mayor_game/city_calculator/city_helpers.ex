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
        buildables_map
      ) do
    city_preloaded = preload_city_check(city)

    city_baked_direct = bake_details_int(city_preloaded, buildables_map)

    all_buildables = city_baked_direct |> Map.take(buildables_map.buildables_list)

    # I think this looks like a keyword list with {type of buildable, list of actual buildables}

    ordered_buildables =
      Enum.map(buildables_map.buildables_ordered_flat, fn x -> {x, all_buildables[x]} end)

    ordered_buildables_flat = Enum.flat_map(ordered_buildables, fn {_, v} -> v end)

    # sorted_citizens = Enum.sort_by(city_baked_direct.citizens, & &1.education, :desc)

    citizens_blob_atoms =
      Enum.map(city_baked_direct.citizens_blob, fn citizen ->
        for {key, val} <- citizen,
            into: %{},
            do: {String.to_existing_atom(key), val}
      end)
      |> Enum.map(fn citizen -> citizen |> Map.merge(%{has_job: false, town_id: city.id}) end)

    sorted_blob_citizens = Enum.sort_by(citizens_blob_atoms, & &1.education, :desc)

    citizen_count = length(sorted_blob_citizens)

    # reduce citizens from highest level
    # look at buildables

    # initial struct
    results = %{
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
      result_buildables: [],
      updated_buildable_count: 0
    }

    results = activation_rounds_recursive(results, ordered_buildables_flat, city, season, 0)

    # IO.inspect(results_after_2nd_round_jobs.jobs)

    all_citizens =
      Enum.sort_by(results.employed_citizens ++ results.citizens, & &1.education, :desc)

    # ________________________________________________________________________
    # Iterate through citizens
    # ________________________________________________________________________
    pollution_reached = world.pollution > pollution_ceiling
    time_to_learn = rem(world.day, 91) == 0

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
          old_citizens: Enum.filter(all_citizens, &(&1.age > 10000)),
          reproducing_citizens: 0
        },
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

          will_citizen_reproduce =
            citizen.age > 500 and citizen.age < 3000 and acc.housing_left > 1 &&
              :rand.uniform(citizen_count + 1) < max(results.health / 100, 5)

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
          # this doesn't account for births
          acc
          |> Map.update!(
            :all_citizens_persisting,
            if(!pollution_death && citizen_not_too_old,
              do: &[updated_citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :housing_left,
            if(acc.housing_left > 0 and !pollution_death and citizen_not_too_old,
              do: &(&1 - housing_taken),
              else: & &1
            )
          )
          |> Map.update!(
            :education_left,
            if(will_citizen_learn,
              do: fn current -> Map.update!(current, updated_citizen.education, &(&1 - 1)) end,
              else: & &1
            )
          )
          |> Map.update!(
            :educated_citizens,
            if(will_citizen_learn,
              do: fn current -> Map.update!(current, updated_citizen.education, &(&1 + 1)) end,
              else: & &1
            )
          )
          |> Map.update!(
            :unemployed_citizens,
            if(
              acc.housing_left > 0 && !citizen.has_job && citizen_not_too_old && !pollution_death,
              do: &[updated_citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :unhoused_citizens,
            if(acc.housing_left <= 0 && citizen_not_too_old && !pollution_death,
              do: &[updated_citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :housed_employed_staying_citizens,
            if(employable && !tax_too_high, do: &[updated_citizen | &1], else: & &1)
          )
          |> Map.update!(
            :employed_looking_citizens,
            if(
              employable && tax_too_high &&
                updated_citizen.last_moved < world.day - 10 * updated_citizen.education,
              do: &[updated_citizen | &1],
              else: & &1
            )
          )
          |> Map.update!(
            :polluted_citizens,
            if(pollution_death && citizen_not_too_old, do: &[updated_citizen | &1], else: & &1)
          )
          # TODO: make this an int instead of a list
          # could do for above as well (list of polluted citizens)
          |> Map.update!(
            :reproducing_citizens,
            if(will_citizen_reproduce,
              do: &(&1 + 1),
              else: & &1
            )
          )
        end
      )
      |> Enum.into(%{})

    # IO.inspect(after_citizen_checks.housing_left)

    city_baked_direct
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

  # @doc """
  # returns a preference map for citizens
  # """
  # def create_citizen_preference_map() do
  #   decision_factors = Enum.shuffle([:tax_rates, :sprawl, :fun, :health, :pollution])

  #   random_preferences =
  #     Enum.reduce(decision_factors, %{preference_map: %{}, room_taken: 0}, fn x, acc ->
  #       value =
  #         if x == List.last(decision_factors),
  #           do: (1 - acc.room_taken) |> Float.round(2),
  #           else: (:rand.uniform() * (1 - acc.room_taken)) |> Float.round(2)

  #       %{
  #         preference_map: Map.put(acc.preference_map, to_string(x), value),
  #         room_taken: acc.room_taken + value
  #       }
  #     end)

  #   random_preferences.preference_map
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
        ),
      new_gold:
        if(!prod_nil and Map.has_key?(prod_map_mult, :gold),
          do: prod_map_mult.gold,
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
    Enum.reduce(buildables_map.buildables_list, town, fn buildable_list_item, town_acc ->
      buildable_count = Map.get(town_acc, buildable_list_item)

      # if Map.has_key?(town_acc, buildable_list_item) && buildable_count > 0 do

      buildable_metadata = Map.get(buildables_map.buildables_flat, buildable_list_item)

      updated_price = building_price(buildable_metadata.price, buildable_count)

      buildable_metadata_price_updated = %MayorGame.City.BuildableMetadata{
        buildable_metadata
        | price: updated_price
      }

      # NO FLOW
      combined_array =
        if buildable_count <= 0 do
          []
        else
          Enum.map(1..buildable_count, fn _x ->
            buildable_metadata_price_updated
          end)
        end

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

      %{town_acc | buildable_list_item => combined_array}
      # else
      # town_acc
      # end
    end)
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
    |> Enum.take(required_count)
  end

  defp activation_rounds_recursive(result_blob, buildables, city, season, education_diff) do
    count = result_blob.updated_buildable_count
    result_blob = activation_round(result_blob, buildables, city, season, education_diff)

    if result_blob.updated_buildable_count > count do
      # filter buildables for the next round of checks
      buildables_split_by_jobs =
        Enum.split_with(result_blob.result_buildables, fn y ->
          !y.enabled && (is_nil(y.jobs) || y.jobs > 0)
        end)

      result_blob_input =
        result_blob |> Map.put(:result_buildables, elem(buildables_split_by_jobs, 1))

      activation_rounds_recursive(
        result_blob_input,
        elem(buildables_split_by_jobs, 0),
        city,
        season,
        education_diff + 1
      )
    else
      result_blob
    end
  end

  defp activation_round(result_blob, buildables, city, season, education_diff) do
    Enum.reduce(
      buildables,
      result_blob,
      fn individual_buildable, acc ->
        # if the building has no requirements
        # if building has requirements
        if individual_buildable.requires == nil do
          updated_buildable =
            individual_buildable
            |> Map.merge(%{
              reason: [],
              enabled: true,
              jobs: 0
            })

          # generate final production map
          update_generated_acc(
            updated_buildable,
            length(acc.citizens),
            city.region,
            season,
            acc
          )
          |> Map.update!(:result_buildables, fn current ->
            [updated_buildable | current]
          end)
        else
          reqs_minus_workers = Map.drop(individual_buildable.requires, [:workers])
          checked_reqs = check_reqs(reqs_minus_workers, acc)

          # if all reqs are met
          if checked_reqs == [] do
            money_required =
              if Map.has_key?(individual_buildable.requires, :money),
                do: individual_buildable.requires.money,
                else: 0

            # if it requires workers

            if Map.has_key?(individual_buildable.requires, :workers) &&
                 individual_buildable.jobs != 0 do
              # here I could just mark that buildable as "enabled pre_workers" or "ready_for_workers" I think?
              # then loop through jobs outside this loop
              # could also just look through the jobs not taken outside the loop and check citizens there?

              required_worker_count =
                if individual_buildable.jobs == nil do
                  individual_buildable.requires.workers.count
                else
                  individual_buildable.jobs
                end

              checked_workers =
                check_workers(
                  individual_buildable.requires,
                  acc.citizens,
                  required_worker_count,
                  education_diff
                )

              checked_workers_count = length(checked_workers)

              enough_workers = checked_workers_count >= required_worker_count

              updated_buildable =
                if !enough_workers do
                  individual_buildable
                  |> Map.merge(%{
                    reason: [:workers],
                    enabled: false,
                    jobs: required_worker_count - checked_workers_count
                  })
                else
                  # if all conditions are met
                  individual_buildable
                  |> Map.merge(%{
                    reason: [],
                    enabled: true,
                    jobs: 0
                  })
                end

              tax_earned =
                calculate_earnings(
                  checked_workers_count,
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
                      acc
                    )
                    |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
                    |> Map.merge(%{
                      income: acc.income + tax_earned,
                      daily_cost: acc.daily_cost + money_required,
                      money: acc.money + tax_earned - money_required,
                      updated_buildable_count: acc.updated_buildable_count + 1
                    }),
                  else: acc

              # update acc with disabled buildable

              acc_after_workers
              |> Map.update!(:employed_citizens, fn currently_employed ->
                Enum.map(checked_workers, fn cit -> Map.put(cit, :has_job, true) end) ++
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
                  &(&1 + required_worker_count - checked_workers_count)
                )
              end)
              |> Map.update!(:total_jobs, fn current_total_jobs_map ->
                Map.update!(
                  current_total_jobs_map,
                  individual_buildable.requires.workers.level,
                  &(&1 + required_worker_count)
                )
              end)
              |> Map.update!(:result_buildables, fn current ->
                [updated_buildable | current]
              end)

              # if number is less than reqs.workers.count, buildable is disabled, reason workers
              # add jobs equal to workers.count - length

              # remove citizens from acc.citizens
              # add them to acc.employed_citizens
            else
              # if it's operating fine & doesn't require workers
              updated_buildable =
                individual_buildable
                |> Map.merge(%{
                  reason: [],
                  enabled: true,
                  jobs: 0
                })

              update_generated_acc(
                updated_buildable,
                length(acc.citizens),
                city.region,
                season,
                acc
              )
              |> Map.merge(reqs_minus_workers, fn _k, v1, v2 -> v1 - v2 end)
              |> Map.update!(:result_buildables, fn current ->
                [updated_buildable | current]
              end)
              |> Map.merge(%{
                daily_cost: acc.daily_cost + money_required,
                updated_buildable_count: acc.updated_buildable_count + 1
              })
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
            Map.update!(acc, :result_buildables, fn current ->
              [updated_buildable | current]
            end)
          end
        end
      end
    )
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
