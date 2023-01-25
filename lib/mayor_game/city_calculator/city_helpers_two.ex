defmodule MayorGame.CityHelpersTwo do
  alias MayorGame.City
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
          money: city_baked_details.treasury,
          income: 0,
          daily_cost: 0,
          citizen_count: length(sorted_citizens),
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
          if buildable_array == [] do
            # for each set of buildables
            acc
          else
            # for each individual buildable:
            Enum.reduce(buildable_array, acc, fn individual_buildable, acc2 ->
              # if the building has no requirements
              # if building has requirements
              if individual_buildable.metadata.requires == nil do
                # generate final production map
                update_generated_acc(individual_buildable, length(acc.citizens), acc2)
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

                    update_generated_acc(individual_buildable, length(acc.citizens), acc2)
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
          end
        end
      )

    all_citizens = results.employed_citizens ++ results.citizens
    # IO.inspect(length(all_citizens), label: "all_citizens")
    # IO.inspect(results.citizen_count, label: "citizen_count")

    # ________________________________________________________________________
    # Iterate through citizens
    # ________________________________________________________________________
    after_citizen_checks =
      all_citizens
      # Flow.from_enumerable(all_citizens)
      # |> Flow.partition()
      |> Enum.reduce(
        # fn ->
        %{
          housing_left: results.housing,
          education_left: results.education,
          educated_citizens: %{0 => [], 1 => [], 2 => [], 3 => [], 4 => [], 5 => []},
          housed_unemployed_citizens: [],
          housed_employed_staying_citizens: [],
          housed_employed_looking_citizens: [],
          unhoused_citizens: [],
          polluted_citizens: [],
          old_citizens: [],
          reproducing_citizens: []
        },
        # end,
        fn citizen, acc ->
          pollution_death = world.pollution > pollution_ceiling and :rand.uniform() > 0.95

          housed_unemployed_citizens =
            if acc.housing_left > 0 && !citizen.has_job && citizen.age < 5000 && !pollution_death,
              do: [citizen | acc.housed_unemployed_citizens],
              else: acc.housed_unemployed_citizens

          tax_too_high = :rand.uniform() < city.tax_rates[to_string(citizen.education)]

          housed_employed_staying_citizens =
            if acc.housing_left > 0 && citizen.has_job && citizen.age < 5000 && !tax_too_high &&
                 !pollution_death,
               do: [citizen | acc.housed_employed_staying_citizens],
               else: acc.housed_employed_staying_citizens

          housed_employed_looking_citizens =
            if acc.housing_left > 0 && citizen.has_job && citizen.age < 5000 && tax_too_high &&
                 !pollution_death,
               do: [citizen | acc.housed_employed_looking_citizens],
               else: acc.housed_employed_looking_citizens

          housing_left =
            if acc.housing_left > 0 and !pollution_death,
              do: acc.housing_left - 1,
              else: acc.housing_left

          # unhoused_citizens =
          #   if acc.housing_left > 0, do: tl(acc.unhoused_citizens), else: acc.unhoused_citizens
          #   # could revert this to add only citizens < 5000 and not dying from pollution

          unhoused_citizens =
            if acc.housing_left <= 0 && citizen.age < 5000 && !pollution_death,
              do: [citizen | acc.unhoused_citizens],
              else: acc.unhoused_citizens

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
              acc.education_left[citizen.education + 1] > 0 && citizen.age < 5000 &&
              !pollution_death

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
      # |> Enum.to_list()
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
        Map.replace(production_map, :pollution, production_map.pollution.(citizen_count / 10))
      else
        production_map
      end

    if production_map == nil do
      totals
    else
      Map.merge(results, totals)
    end
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

  def building_price(initial_price, buildable_count) do
    initial_price * round(:math.pow(buildable_count, 2) + 1)
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
