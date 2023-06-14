defmodule MayorGame.CityHelpers do
  alias MayorGame.City.{
    Town,
    World,
    Citizens,
    ResourceStatistics,
    BuildableStatistics,
    TownStatistics,
    TownMigrationStatistics
  }

  alias MayorGame.{City}

  alias MayorGame.Rules

  import Ecto.Query, warn: false

  def unfold_town_citizens(town, day) do
    unfolded_citizens = town.citizens_compressed |> Citizens.unfold_citizen_blob(day, town.id)

    Map.put(town, :citizens_blob, unfolded_citizens)
  end

  @doc """
    takes a %Town{} struct and %World{} struct

    returns a MayorGame.City.TownStatistics:
    ```
  """
  def calculate_city_stats(
        %Town{} = town,
        %World{} = world,
        _pollution_ceiling,
        _season,
        buildables_map,
        _in_dev,
        _time_to_learn
      ) do
    town_preloaded = unfold_town_citizens(town, world.day)

    town_stats = TownStatistics.fromTown(town_preloaded, world)

    # ok I do get the count here from town_stats.total_citizens

    # I don't think I need to do anything fancy here?

    priorities_atoms =
      for {key, val} <- town_stats.priorities,
          into: %{},
          do: {String.to_existing_atom(key), val}

    sorted_buildables = buildables_map.buildables_list |> Enum.sort_by(&priorities_atoms[&1])

    buildable_type_count_squared = length(sorted_buildables) * length(sorted_buildables)

    # need an array of food types to iterate through

    # food_resources = [:food, :fish, :meat, :bread, :produce, :rice, :grapes]
    food_resources = [food: 1000, fish: 200, meat: 500, bread: 100, produce: 100, rice: 200, grapes: 20]

    # returns a town_stats with food_consumed and actual resources consumed

    town_stats_after_food =
      Enum.reduce_while(food_resources, town_stats, fn {food_type, food_amount}, acc ->
        hungry_citizens = town_stats.total_citizens - acc.food_consumed

        if acc.food_consumed >= town_stats.total_citizens do
          # if there's more or equal food to the citizen count
          {:halt, acc}
        else
          max_possible_food = acc |> TownStatistics.getResource(food_type) |> ResourceStatistics.getNextStock()

          max_possible_food =
            min(max_possible_food, acc |> TownStatistics.getResource(food_type) |> ResourceStatistics.getStorage())

          # IO.inspect(max_possible_food, label: town.title <> " max_possible_food " <> to_string(food_type))

          food_production_resources =
            ResourceStatistics.merge(
              acc
              |> TownStatistics.getResource(food_type),
              ResourceStatistics.fromRequires(
                to_string(food_type),
                min(round(hungry_citizens / food_amount), max_possible_food)
              )
            )

          # 4 bread at 10
          # 100 hungry citizens
          # min(10, 4)

          {:cont,
           acc
           |> put_in([:resource_stats, food_type], food_production_resources)
           |> Map.put(:food_consumed, acc.food_consumed + max_possible_food * food_amount)}
        end
      end)

    # returns a %TownStatistics{}
    results_before_overrides =
      Enum.reduce_while(
        # the worst case scenario would be a square of this number, but you'd have to craft the malicious city on purpose.
        1..buildable_type_count_squared,
        town_stats_after_food,
        fn _iter, acc ->
          {cont_or_halt, _, updated_acc} =
            Enum.reduce_while(
              sorted_buildables,
              {:halt, [], acc},
              fn buildable, {loop_decision, pending_req, town_stat_inner} ->
                # funky, you can do this with tuples

                {fulfilled_count, sub_produces, sub_consumes, sub_town_stats} =
                  fill_workers(town, town_stat_inner, buildables_map.buildables_flat[buildable])

                if is_nil(sub_produces) || length(sub_produces) == 0 || fulfilled_count <= 0 do
                  {:cont, {loop_decision, pending_req, sub_town_stats}}
                else
                  # intersection of sub_produces and pending_req
                  # if there is something there, it means this buildable has produced something that is unmet by buildings ahead in priority. We should go back to the head to fill those buildings
                  temp = sub_produces -- pending_req
                  met_prev_req = sub_produces -- temp

                  if length(met_prev_req) > 0 do
                    # reset to the first buildable
                    {:halt, {:cont, [], sub_town_stats}}
                  else
                    # union of sub_consumes and pending_req
                    # acculmuate any unmet req here for the next buildable
                    temp2 = sub_consumes -- pending_req
                    intercept2 = sub_consumes -- temp2
                    combined_consumes = pending_req ++ (sub_consumes -- intercept2)
                    {:cont, {loop_decision, combined_consumes, sub_town_stats}}
                  end
                end
              end
            )

          {cont_or_halt, updated_acc}
        end
      )

    # set overrides not handled by production calculations
    # this is only needed since the produce code does not consider the starting cap, and it is not additive

    # missiles_cap =
    #   results_before_overrides
    #   |> TownStatistics.getResource(:missiles)
    #   |> ResourceStatistics.getStorage()

    # shields_cap =
    #   results_before_overrides
    #   |> TownStatistics.getResource(:shields)
    #   |> ResourceStatistics.getStorage()

    # adjusted_missiles_cap =
    #   if is_nil(missiles_cap) do
    #     50
    #   else
    #     max(50, missiles_cap)
    #   end

    # adjusted_shields_cap =
    #   if is_nil(shields_cap) do
    #     50
    #   else
    #     max(50, shields_cap)
    #   end

    results =
      results_before_overrides
      |> Map.update!(:resource_stats, fn v ->
        v
        |> Map.merge(
          %{
            # citizens occupy housing
            :housing => ResourceStatistics.fromRequires(:housing, town_stats.total_citizens)
          },
          fn _k, v1, v2 -> ResourceStatistics.merge(v1, v2) end
        )
        |> Enum.map(
          # apply capacities
          fn {k, v} ->
            {k,
             if is_nil(v.storage) || v.storage > v.stock + v.production do
               v
             else
               v
               |> Map.update!(:production, fn _ -> v.storage - v.stock end)
             end}
          end
        )
        |> Enum.into(%{})
      end)

    results
  end

  @doc """
    takes a %TownStatistics{} struct

    returns a MayorGame.City.TownStatistics:
    ```
  """
  def calculate_city_stats_with_drops(
        %Town{} = town,
        %World{} = world,
        pollution_ceiling,
        season,
        buildables_map,
        in_dev,
        time_to_learn
      ) do
    results_before_drops =
      calculate_city_stats(
        town,
        world,
        pollution_ceiling,
        season,
        buildables_map,
        in_dev,
        time_to_learn
      )

    # calc drops
    results_before_overrides =
      results_before_drops
      |> Map.update!(:resource_stats, fn v ->
        v
        |> Enum.map(fn {atom, r} ->
          if is_nil(r.droplist) || length(r.droplist) == 0 do
            {atom, r}
          else
            drops =
              Enum.reduce(r.droplist, 0, fn {qty, func}, acc ->
                if func do
                  acc +
                    cond do
                      # drops (fn _rng, _number_of_instances -> drop_amount)
                      is_function(func, 2) ->
                        result = func.(:rand.uniform(), qty)
                        if is_number(result), do: result, else: 0

                      # drops (fn _rng, _number_of_instances, _city -> drop_amount)
                      is_function(func, 3) ->
                        func.(:rand.uniform(), qty, town)

                      true ->
                        0
                    end
                else
                  acc
                end
              end)

            {atom, ResourceStatistics.merge(r, %ResourceStatistics{:production => drops})}
          end
        end)
        |> Enum.into(%{})
      end)

    # erm, this was already done prior in calculate_city_stats, but we have to do it again in case of drops exceeding the capacity
    # this is not ideal; a better way should be sought after
    missiles_cap =
      results_before_overrides
      |> TownStatistics.getResource(:missiles)
      |> ResourceStatistics.getStorage()

    shields_cap =
      results_before_overrides
      |> TownStatistics.getResource(:shields)
      |> ResourceStatistics.getStorage()

    adjusted_missiles_cap =
      if is_nil(missiles_cap) do
        50
      else
        max(50, missiles_cap)
      end

    adjusted_shields_cap =
      if is_nil(shields_cap) do
        50
      else
        max(50, shields_cap)
      end

    results =
      results_before_overrides
      |> Map.update!(:resource_stats, fn v ->
        v
        |> Map.merge(
          %{
            # apply modified capacities
            :missiles => adjusted_missiles_cap,
            :shields => adjusted_shields_cap
          },
          fn _k, v1, v2 -> v1 |> Map.update!(:storage, fn _ -> v2 end) end
        )
        |> Enum.map(
          # apply capacities
          fn {k, v} ->
            {k,
             if is_nil(v.storage) || v.storage > v.stock + v.production do
               v
             else
               v |> Map.update!(:production, fn _ -> v.storage - v.stock end)
             end}
          end
        )
        |> Enum.into(%{})
      end)

    results
  end

  @doc """
    takes a %TownStatistics{} struct

    returns a MayorGame.City.TownMigrationStatistics:
    ```
  """
  def calculate_citizen_stats(
        %Town{} = town,
        %TownStatistics{} = town_stats,
        %World{} = world,
        pollution_ceiling,
        _season,
        _buildables_map,
        _in_dev,
        time_to_learn
      ) do
    town_preloaded = unfold_town_citizens(town, world.day)

    # ok this does add to the consumption
    # fromRequires adds to the consumption, but not the stock (I think)

    # ok this is total citizen count
    # so try to generate food
    # loop through food categories
    # generate food (integer variable) until it hits the count
    # along the way, need to add to the consumption field for each food category
    # and keep that in town_stats struct
    # but I think I need to do this earlier in town_stats. Doesn't get returned from this function

    # IO.inspect(
    #   ResourceStatistics.merge(
    #     town_stats
    #     |> TownStatistics.getResource(:food),
    #     ResourceStatistics.fromRequires("food", 20)
    #   ),
    #   label: "after_mrge"
    # )

    # IO.inspect(
    #   town_stats
    #   |> TownStatistics.getResource(:food)
    #   |> ResourceStatistics.getNextStock(),
    #   label: "getNextStock"
    # )
    # getNextStock will get the total, including production and consumption
    # so if getNextStock > 0, there's still some food

    # are we sure we want pollution_ceiling to be tied to a RNG?
    # pollution_reached = world.pollution > pollution_ceiling

    pollution_reached =
      world.pollution > pollution_ceiling ||
        town_stats.resource_stats.pollution.production > town_stats.total_citizens * 5

    # if this is all that matters, that's a lot of calls to that function
    # probably can optimize this a bit
    # TODO
    reproductive_citizen_count = Enum.count(town_preloaded.citizens_blob, &Rules.is_citizen_reproductive(&1))

    # this expensive operation may be avoided if we store the birthday instead of the age
    working_citizens =
      Enum.filter(town_preloaded.citizens_blob, &Rules.is_citizen_within_lifespan(&1))
      |> Enum.map(fn citizen -> citizen |> Map.put("town_id", town.id) end)

    # |> Enum.map(fn c -> c |> Map.update!("age", &(&1 + 1)) end)

    # each citizen has a {health}% chance to reproducing, up to a minimum of 5% and maximum of 100%
    # the total reproduction rate cannot exceed the number of remaining housing
    # we can be guaranteed town_stats.resource_stats.housing exists due to the {# citizens occupy housing} block. This might change in the future
    excess_housing = ResourceStatistics.getNetProduction(town_stats.resource_stats.housing)

    aggregate_births =
      round(
        min(
          excess_housing,
          reproductive_citizen_count *
            (town_stats
             |> TownStatistics.getResource(:health)
             |> ResourceStatistics.getNetProduction()
             |> min(2.0)
             |> max(0.1))
        )
      )

    aggregate_deaths_by_age = length(town_preloaded.citizens_blob) - length(working_citizens)

    # if pollution is exceeded, each citizen has a 5% chance of dying from it
    # technically this is factored against all citizens, but old_citizens will be reported to have died of old age, so exclude them
    aggregate_deaths_by_pollution =
      if !pollution_reached do
        0
      else
        floor(length(working_citizens) * 0.05)
      end

    # start random here, exclude live view from calling this. UI does not need to play gacha, that's server's job
    # might be worthwhile to split the above into calculate_city_stats, so the UI has access to
    #  but to do that we probably should eliminate RNG factor from pollution_reached, or results change each refresh

    # sorter
    # 1. Set list to <working_citizens>, scramble (RNG!)
    # 2. Take <aggregate_deaths_by_pollution> members from the list. These are <polluted_citizens>, they will be eliminated so no other processing is done with them
    # 3. If citizen count is less than housing, Take the difference members from the list. These are <unhoused_citizens>, and they will be entered to the migration pool, so no other processing is done with them.
    # 4. Group the rest by education, scramble each group (...or do we need to? It is already scrambled at Step 1)
    # 5. Take <employed_citizen_count_by_level[education]> members from each group. It does not matter if there are less citizens than employed due to previous steps.
    # 6. Flatten the remainder; these are <unemployed_citizens>, and they will be entered to the migration pool, so no other processing is done with them.
    # 7. Get the members from Step 5, take members by proportion of <tax_too_high> (calc per edu level). These are <migrating_citizens_due_to_tax>
    # 8. Scan through the remainder, take members based on their last_moved. Add them to <migrating_citizens>
    # 9. Flatten the remainder; these are <staying_citizens>
    # 10. Apply education to <staying_citizens>

    # calculate education tokens
    # education (not education_lvl_1) are distributed randomly
    edu_generic =
      town_stats
      |> TownStatistics.getResource(:education)
      |> ResourceStatistics.getNetProduction()

    edu_promotions =
      if edu_generic == 0 do
        %{
          0 =>
            town_stats
            |> TownStatistics.getResource(:education_lvl_1)
            |> ResourceStatistics.getNetProduction(),
          1 =>
            town_stats
            |> TownStatistics.getResource(:education_lvl_2)
            |> ResourceStatistics.getNetProduction(),
          2 =>
            town_stats
            |> TownStatistics.getResource(:education_lvl_3)
            |> ResourceStatistics.getNetProduction(),
          3 =>
            town_stats
            |> TownStatistics.getResource(:education_lvl_4)
            |> ResourceStatistics.getNetProduction(),
          4 =>
            town_stats
            |> TownStatistics.getResource(:education_lvl_5)
            |> ResourceStatistics.getNetProduction(),
          5 => 0
        }
      else
        rand_5 = %{
          0 => :rand.uniform(),
          1 => :rand.uniform(),
          2 => :rand.uniform(),
          3 => :rand.uniform(),
          4 => :rand.uniform()
        }

        rand_sum = rand_5 |> Map.values() |> Enum.sum()

        %{
          0 =>
            (town_stats
             |> TownStatistics.getResource(:education_lvl_1)
             |> ResourceStatistics.getNetProduction()) + round(rand_5[0] * edu_generic / rand_sum),
          1 =>
            (town_stats
             |> TownStatistics.getResource(:education_lvl_2)
             |> ResourceStatistics.getNetProduction()) + round(rand_5[1] * edu_generic / rand_sum),
          2 =>
            (town_stats
             |> TownStatistics.getResource(:education_lvl_3)
             |> ResourceStatistics.getNetProduction()) + round(rand_5[2] * edu_generic / rand_sum),
          3 =>
            (town_stats
             |> TownStatistics.getResource(:education_lvl_4)
             |> ResourceStatistics.getNetProduction()) + round(rand_5[3] * edu_generic / rand_sum),
          4 =>
            (town_stats
             |> TownStatistics.getResource(:education_lvl_5)
             |> ResourceStatistics.getNetProduction()) + round(rand_5[4] * edu_generic / rand_sum),
          5 => 0
        }
      end

    # 1. Set list to <working_citizens>, scramble (RNG!)
    scrambled_working_citizens = working_citizens |> Enum.shuffle()

    # 2. Take <aggregate_deaths_by_pollution> members from the list. These are <polluted_citizens>, they will be eliminated so no other processing is done with them
    {polluted_citizens, unpolluted_citizens} = scrambled_working_citizens |> Enum.split(aggregate_deaths_by_pollution)

    {fed_citizens, starved_citizens} = unpolluted_citizens |> Enum.split(town_stats.food_consumed)

    unpolluted_citizens_by_level = fed_citizens |> Enum.group_by(& &1["education"])

    # apply education
    {unpolluted_citizens_after_education, promoted_citizens_qty} =
      unpolluted_citizens_by_level
      |> Enum.flat_map_reduce(
        %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0},
        fn {level, unpolluted_citizens_in_level}, acc ->
          # 10. Apply education to <migrating_citizens> + <staying_citizens>
          {citizens_to_promote, other_citizens} =
            if time_to_learn do
              unpolluted_citizens_in_level |> Enum.split(edu_promotions[level])
            else
              {[], unpolluted_citizens_in_level}
            end

          promoted_citizens = citizens_to_promote |> Enum.map(fn c -> c |> Map.update!("education", &(&1 + 1)) end)

          {promoted_citizens ++ other_citizens, acc |> Map.put(level + 1, length(promoted_citizens))}
        end
      )

    # educated citizens have priority in housing
    # 3. If citizen count is less than housing, Take the difference members from the list. These are <unhoused_citizens>, and they will be entered to the migration pool, so no other processing is done with them.
    {unhoused_citizens, housed_citizens} =
      unpolluted_citizens_after_education
      |> Enum.sort_by(& &1["education"], :asc)
      |> Enum.split(max(0, -excess_housing))

    # ok I could do the same thing here by the total amount of food
    # I think I have a path here
    # generate food until it meets citizen count
    # probably should put food before housing and pollution
    # oh this is a bit different because… should lack of food just kill them immediately? like pollution? Or could they move for food?
    # if kills immediately, shoudl go before unhoused filter
    # {unhoused_citizens, housed_citizens} =
    #   unpolluted_citizens_after_education
    #   |> Enum.sort_by(& &1["education"], :asc)
    #   |> Enum.split(max(0, -excess_housing))

    # 4. Group the rest by education
    housed_citizens_by_level = housed_citizens |> Enum.group_by(& &1["education"])

    # 5. Take <employed_citizen_count_by_level[education]> members from each group. It does not matter if there are less citizens than employed due to previous steps.
    # 7. Get the members from Step 5, take members by proportion of <tax_too_high> (calc per edu level). These are <migrating_citizens_due_to_tax>
    sorted_housed_citizens_by_level =
      housed_citizens_by_level
      |> Enum.map(fn {level, list} ->
        employed_citizen_count_in_level =
          if is_nil(town_stats.employed_citizen_count_by_level[level]) do
            0
          else
            town_stats.employed_citizen_count_by_level[level]
          end

        {employed_citizens_in_level, unemployed_citizens_in_level} = list |> Enum.split(employed_citizen_count_in_level)

        {migrating_by_tax_citizens_in_level, needs_met_citizens_in_level} =
          employed_citizens_in_level
          |> Enum.split(
            floor(
              length(employed_citizens_in_level) *
                Rules.excessive_tax_chance(level, town_stats.tax_rates[to_string(level)])
            )
          )

        {level, needs_met_citizens_in_level, unemployed_citizens_in_level, migrating_by_tax_citizens_in_level}
      end)

    # 6. Flatten the remainder; these are <unemployed_citizens>, and they will be entered to the migration pool, so no other processing is done with them.
    unemployed_citizens =
      sorted_housed_citizens_by_level
      |> Enum.flat_map(fn {_, _, unemployed_citizens_in_level, _} ->
        unemployed_citizens_in_level
      end)

    migrating_by_tax_citizens =
      sorted_housed_citizens_by_level
      |> Enum.flat_map(fn {_, _, _, migrating_by_tax_citizens_in_level} ->
        migrating_by_tax_citizens_in_level
      end)

    # !!!! migrating_citizens and migrating_by_tax_citizens may include people will simply 'migrate' back to the same city!
    needs_met_citizens =
      sorted_housed_citizens_by_level
      |> Enum.flat_map(fn {_, needs_met_citizens_in_level, _, _} ->
        needs_met_citizens_in_level
      end)

    # 8. Scan through the remainder, take members based on their last_moved. Add them to <migrating_citizens>
    {migrating_citizens, staying_citizens} =
      needs_met_citizens |> Enum.split_with(fn c -> Rules.is_citizen_restless(c, world) end)

    TownMigrationStatistics.fromTown(town_preloaded)
    |> Map.merge(%{
      aggregate_births: aggregate_births,
      aggregate_deaths_by_age: aggregate_deaths_by_age,
      aggregate_deaths_by_pollution: aggregate_deaths_by_pollution,
      aggregate_deaths_by_starvation: length(starved_citizens),
      housing_left: excess_housing - aggregate_births,
      staying_citizens: staying_citizens,
      migrating_citizens_due_to_tax: migrating_by_tax_citizens,
      migrating_citizens: migrating_citizens,
      unemployed_citizens: unemployed_citizens,
      unhoused_citizens: unhoused_citizens,
      polluted_citizens: polluted_citizens,
      starved_citizens: starved_citizens,
      educated_citizens: promoted_citizens_qty
    })
  end

  @spec get_production_map(map() | nil, map() | nil, integer, String.t(), atom) :: map
  def get_production_map(production_map, multiplier_map, _citizen_count, region, season) do
    # this is fetched by web live and server-side calculations
    if is_nil(multiplier_map),
      do: production_map,
      else: production_map |> multiply(multiplier_map, region, season)
  end

  @spec render_production_supply(map() | nil, map() | nil, TownStatistics.t(), integer) :: %{
          String.t() => ResourceStatistics.t()
        }
  def render_production_supply(production_map, multiplier_map, town, multiple \\ 1) do
    if is_nil(production_map) do
      %{}
    else
      get_production_map(production_map, multiplier_map, town.total_citizens, town.region, town.season)
      |> Enum.map(fn {k, v} ->
        value =
          cond do
            # bug-fix: multiplers will always generate a float, use is_number instead of is_integer
            is_number(v) -> round(v)
            # pollution per pop (consider making generic)
            is_function(v, 1) -> round(v.(town.total_citizens))
            true -> 0
          end

        droplist =
          cond do
            # education and uranium drops
            # drops (fn _rng, _number_of_instances -> drop_amount)
            is_function(v, 2) -> [{multiple, v}]
            # currently unused
            # drops (fn _rng, _number_of_instances, _city -> drop_amount)
            is_function(v, 3) -> [{multiple, v}]
            true -> []
          end

        {k, ResourceStatistics.fromProduces(k, value * multiple, nil, droplist)}
      end)
      |> Enum.into(%{})
    end
  end

  @spec render_production_store(map() | nil, map() | nil, TownStatistics.t(), integer) :: %{
          String.t() => ResourceStatistics.t()
        }
  def render_production_store(production_map, multiplier_map, town, multiple \\ 1) do
    if is_nil(production_map) do
      %{}
    else
      citizen_count = Enum.sum(Map.values(town.citizen_count_by_level))

      get_production_map(production_map, multiplier_map, citizen_count, town.region, town.season)
      |> Enum.map(fn {k, v} ->
        value =
          cond do
            is_number(v) -> round(v)
            true -> nil
          end

        {k,
         ResourceStatistics.fromProduces(
           k,
           0,
           if is_nil(value) do
             nil
           else
             value * multiple
           end,
           []
         )}
      end)
      |> Enum.into(%{})
    end
  end

  @spec render_production_consumption(map() | nil, map() | nil, TownStatistics.t(), integer) :: %{
          String.t() => ResourceStatistics.t()
        }
  def render_production_consumption(production_map, multiplier_map, town, multiple \\ 1) do
    if is_nil(production_map) do
      %{}
    else
      citizen_count = Enum.sum(Map.values(town.citizen_count_by_level))

      get_production_map(production_map, multiplier_map, citizen_count, town.region, town.season)
      |> Enum.map(fn {k, v} ->
        value =
          cond do
            is_number(v) -> round(v)
            # pollution per pop
            is_function(v, 1) -> round(v.(citizen_count))
            # drops not supported for consumption
            true -> 0
          end

        {k, ResourceStatistics.fromRequires(k, value * multiple, nil)}
      end)
      |> Enum.into(%{})
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

        region_atom = String.to_existing_atom(region)

        v_x_region =
          if Map.has_key?(multipliers, :region) && Map.has_key?(multipliers.region, k) &&
               Map.has_key?(multipliers.region[k], region_atom),
             do: round(v_x_season * multipliers.region[k][region_atom]),
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
      town
      |> MayorGame.Repo.preload([
        :user,
        :attacking,
        :attacked,
        :attacks_sent,
        :attacks_recieved,
        :sanctioning,
        :sanctioned,
        :sanctions_sent,
        :sanctions_recieved
      ])
    else
      town
    end
  end

  # the first list in the tuple indicates what is produced. This will be used to determine if the loop should reset to its start of the sorted_buildables list
  # the second list in the tuple indicates what is prevents all buildables from being activated. This will be used to determine if the loop should reset to its start of the sorted_buildables list
  @spec fill_workers(Town.t(), TownStatistics.t(), BuildableMetadata.t()) ::
          {integer, list(), list(), TownStatistics.t()}
  def fill_workers(town, town_stats, buildable) do
    buildable_count =
      if Map.has_key?(town_stats.buildable_stats, buildable.title) do
        Map.get(town, buildable.title) - town_stats.buildable_stats[buildable.title].operational
      else
        town[buildable.title]
      end

    if buildable_count < 1 do
      {
        0,
        [],
        [],
        town_stats
      }
    else
      if !Map.has_key?(buildable, :requires) || is_nil(buildable.requires) do
        # if it doesn't require anything
        new_buildable = %BuildableStatistics{
          title: buildable.title,
          number: buildable_count,
          operational: buildable_count,
          workers_by_level: %{},
          deficient_prereq_next: [],
          deficient_prereq_all: [],
          resource: %{}
        }

        new_buildable_stats =
          town_stats.buildable_stats
          |> Map.update(buildable.title, new_buildable, fn _v -> new_buildable end)

        production =
          render_production_supply(
            buildable.produces,
            buildable.multipliers,
            town_stats,
            buildable_count
          )

        new_supply =
          Map.merge(production, town_stats.resource_stats, fn _k, v1, v2 ->
            ResourceStatistics.merge(v1, v2)
          end)

        {
          buildable_count,
          Map.keys(production),
          [],
          town_stats
          |> Map.put(:buildable_stats, new_buildable_stats)
          |> Map.put(:resource_stats, new_supply)
        }
      else
        reqs_minus_workers = Map.drop(buildable.requires, [:workers])

        # application of requires multiples possibly here

        # %{
        #  fulfilled_count: the number that can fulfill reqs, up to count provided to the function,
        #  deficient_prereq_next: Reqs not met for the next instance of building
        #  deficient_prereq_all: Reqs not met to fulfill all instances of the building
        # }
        pre_employment_operation_stats =
          check_maximum_and_reqs(town_stats.resource_stats, reqs_minus_workers, buildable_count)

        # %{
        #  fulfilled_count: the number that can fulfill reqs, up to count provided to the function,
        #  deficient_prereq_next: Reqs not met for the next instance of building
        #  deficient_prereq_all: Reqs not met to fulfill all instances of the building
        #  jobs_by_level: a %{integer => integer} map of levels for job positions,
        #  vacancies_by_level: a %{integer => integer} map of levels for job positions,
        #  workers_by_level: a %{integer => integer} map of levels to the count of workers that took the job,
        #  employed_citizen_count_by_level: the updated employed_citizen_count_by_level
        #  employment_vacancies: remaining vacancies
        # }
        post_employment_operation_stats =
          if Map.has_key?(buildable.requires, :workers) do
            required_worker_count = buildable.requires.workers.count * pre_employment_operation_stats.fulfilled_count

            # %{
            #  jobs_by_level: a %{integer => integer} map of levels for job positions,
            #  workers_by_level: a %{integer => integer} map of levels to the count of workers that took the job,
            #  employed_citizen_count_by_level: the updated employed_citizen_count_by_level
            #  employment_vacancies: remaining vacancies
            # }
            checked_workers_stats =
              check_worker_count(
                buildable.requires.workers.level,
                town_stats.citizen_count_by_level,
                town_stats.employed_citizen_count_by_level,
                required_worker_count
              )

            if checked_workers_stats.employment_vacancies < 1 do
              Map.merge(pre_employment_operation_stats, checked_workers_stats)
              |> Map.put(:vacancies_by_level, %{
                buildable.requires.workers.level => checked_workers_stats.employment_vacancies
              })
            else
              Map.merge(checked_workers_stats, %{
                vacancies_by_level: %{
                  buildable.requires.workers.level => checked_workers_stats.employment_vacancies
                },
                fulfilled_count:
                  floor(
                    (required_worker_count - checked_workers_stats.employment_vacancies) /
                      buildable.requires.workers.count
                  ),
                deficient_prereq_next: [:workers],
                deficient_prereq_all: pre_employment_operation_stats.deficient_prereq_all ++ [:workers]
              })
            end
          else
            Map.merge(pre_employment_operation_stats, %{
              jobs_by_level: %{},
              vacancies_by_level: %{},
              workers_by_level: %{},
              employed_citizen_count_by_level: town_stats.employed_citizen_count_by_level,
              employment_vacancies: 0
            })
          end

        # calculate tax // # this can be precalculated
        tax_earned =
          if post_employment_operation_stats.fulfilled_count > 0 do
            ResourceStatistics.fromProduces(
              :money,
              if !Map.has_key?(buildable.requires, :workers) do
                0
              else
                Rules.calculate_earnings(
                  buildable.requires.workers.count *
                    post_employment_operation_stats.fulfilled_count,
                  buildable.requires.workers.level,
                  town_stats.tax_rates[to_string(buildable.requires.workers.level)]
                )
              end,
              nil
            )
          else
            ResourceStatistics.fromProduces(:money, 0, nil)
          end

        # update production and consumption
        # %{String.t() => ResourceStatistics.t()}
        production =
          render_production_supply(
            buildable.produces,
            buildable.multipliers,
            town_stats,
            post_employment_operation_stats.fulfilled_count
          )
          |> Map.merge(%{:money => tax_earned}, fn _k, v1, v2 ->
            ResourceStatistics.merge(v1, v2)
          end)

        consumption =
          render_production_consumption(
            buildable.requires,
            nil,
            town_stats,
            post_employment_operation_stats.fulfilled_count
          )

        storage =
          render_production_store(
            buildable.stores,
            nil,
            town_stats,
            post_employment_operation_stats.fulfilled_count
          )

        change =
          Map.merge(production, consumption, fn _k, v1, v2 -> ResourceStatistics.merge(v1, v2) end)
          |> Map.merge(storage, fn _k, v1, v2 -> ResourceStatistics.merge(v1, v2) end)

        new_supply =
          Map.merge(town_stats.resource_stats, change, fn _k, v1, v2 ->
            ResourceStatistics.merge(v1, v2)
          end)

        new_buildable =
          if Map.has_key?(town_stats.buildable_stats, buildable.title) do
            %BuildableStatistics{
              title: buildable.title,
              number: town_stats.buildable_stats[buildable.title].number,
              operational:
                town_stats.buildable_stats[buildable.title].operational +
                  post_employment_operation_stats.fulfilled_count,
              workers_by_level:
                town_stats.buildable_stats[buildable.title].workers_by_level
                |> Map.merge(post_employment_operation_stats.workers_by_level, fn _k, v1, v2 ->
                  v1 + v2
                end),
              deficient_prereq_next: post_employment_operation_stats.deficient_prereq_next,
              deficient_prereq_all: post_employment_operation_stats.deficient_prereq_all,
              resource:
                town_stats.buildable_stats[buildable.title].resource
                |> Map.merge(change, fn _k, v1, v2 -> ResourceStatistics.merge(v1, v2) end)
            }
          else
            %BuildableStatistics{
              title: buildable.title,
              number: buildable_count,
              operational: post_employment_operation_stats.fulfilled_count,
              workers_by_level: post_employment_operation_stats.workers_by_level,
              deficient_prereq_next: post_employment_operation_stats.deficient_prereq_next,
              deficient_prereq_all: post_employment_operation_stats.deficient_prereq_all,
              resource: change
            }
          end

        new_buildable_stats =
          town_stats.buildable_stats
          |> Map.update(buildable.title, new_buildable, fn _v -> new_buildable end)

        new_job_stats =
          town_stats.jobs_by_level
          |> Map.merge(post_employment_operation_stats.jobs_by_level, fn _k, v1, v2 -> v1 + v2 end)

        new_job_taken_stats =
          town_stats.vacancies_by_level
          |> Map.merge(post_employment_operation_stats.vacancies_by_level, fn _k, v1, v2 ->
            v1 + v2
          end)

        {
          post_employment_operation_stats.fulfilled_count,
          Map.keys(production),
          post_employment_operation_stats.deficient_prereq_all,
          town_stats
          |> Map.put(:jobs_by_level, new_job_stats)
          |> Map.put(:vacancies_by_level, new_job_taken_stats)
          |> Map.put(
            :employed_citizen_count_by_level,
            post_employment_operation_stats.employed_citizen_count_by_level
          )
          |> Map.put(:buildable_stats, new_buildable_stats)
          |> Map.put(:resource_stats, new_supply)
        }
      end
    end
  end

  @doc """
   Returns %{
    fulfilled_count: the number that can fulfill reqs, up to count provided to the function,
    deficient_prereq_next: Reqs not met for the next instance of building
    deficient_prereq_all: Reqs not met to fulfill all instances of the building
  }
  """
  @spec check_maximum_and_reqs(%{String.t() => ResourceStatistics.t()}, %{}, integer) :: %{
          fulfilled_count: integer,
          deficient_prereq_next: list(String.t()),
          deficient_prereq_all: list(String.t())
        }
  def check_maximum_and_reqs(reqs, checkee, count) do
    # !!!! reqs might not necessarily contain all elements of checkee! Filtering reqs is not enough.
    # If any of the checkees are not present in reqs, and checkees is a true requirement, it is demanding a resource that is not produced.
    # In such a case, evaluate to 0

    checkee_keys_without_reqs =
      Map.filter(checkee, fn {k, _v} -> !is_nil(checkee[k]) && checkee[k] > 0 && is_nil(reqs[k]) end) |> Map.keys()

    if length(checkee_keys_without_reqs) > 0 do
      %{
        fulfilled_count: 0,
        deficient_prereq_next: checkee_keys_without_reqs,
        deficient_prereq_all: checkee_keys_without_reqs
      }
    else
      filtered_reqs = Map.filter(reqs, fn {k, _v} -> !is_nil(checkee[k]) && checkee[k] > 0 end)

      met_values =
        Enum.map(filtered_reqs, fn {k, v} ->
          {k, floor((v.production - v.consumption + Enum.max([0, v.stock])) / checkee[k])}
        end)

      # note: fulfilled_count may be negative
      fulfilled_count = Enum.min(Enum.map(met_values, fn {_k, v} -> v end) ++ [count])

      %{
        fulfilled_count: Enum.max([0, fulfilled_count]),
        deficient_prereq_next:
          if fulfilled_count == count do
            []
          else
            Enum.flat_map(met_values, fn {k, v} ->
              case v <= fulfilled_count do
                true -> [k]
                false -> []
              end
            end)
          end,
        deficient_prereq_all:
          Enum.flat_map(met_values, fn {k, v} ->
            case v < count do
              true -> [k]
              false -> []
            end
          end)
      }
    end
  end

  @spec check_worker_count(integer, %{integer => integer}, %{integer => integer}, integer) :: %{
          jobs_by_level: %{integer => integer},
          workers_by_level: %{integer => integer},
          employed_citizen_count_by_level: %{integer => integer},
          employment_vacancies: integer
        }
  defp check_worker_count(
         job_level,
         citizen_count_by_level,
         employed_citizen_count_by_level,
         required_count
       ) do
    # check if there's already enough citizens at the correct job level
    if Map.get(citizen_count_by_level, job_level, 0) -
         Map.get(employed_citizen_count_by_level, job_level, 0) >= required_count do
      %{
        jobs_by_level: %{job_level => required_count},
        workers_by_level: %{job_level => required_count},
        employed_citizen_count_by_level:
          employed_citizen_count_by_level
          |> Map.update(job_level, required_count, &(&1 + required_count)),
        employment_vacancies: 0
      }
    else
      Enum.reduce_while(
        job_level..6,
        %{
          jobs_by_level: %{job_level => required_count},
          employed_citizen_count_by_level: employed_citizen_count_by_level,
          workers_by_level: %{},
          employment_vacancies: required_count
        },
        fn level, acc ->
          take_count =
            min(
              Map.get(citizen_count_by_level, level, 0) -
                Map.get(acc.employed_citizen_count_by_level, level, 0),
              acc.employment_vacancies
            )

          if take_count < 1 do
            # no remaining employees at this level
            {:cont, acc}
          else
            updated_acc = %{
              # acc.jobs_by_level |> Map.put(level, take_count),
              jobs_by_level: acc.jobs_by_level,
              employed_citizen_count_by_level:
                acc.employed_citizen_count_by_level
                |> Map.update(level, take_count, &(&1 + take_count)),
              workers_by_level: acc.workers_by_level |> Map.update(level, take_count, &(&1 + take_count)),
              employment_vacancies: acc.employment_vacancies - take_count
            }

            if updated_acc.employment_vacancies < 1 do
              # positions filled
              {:halt, updated_acc}
            else
              {:cont, updated_acc}
            end
          end
        end
      )
    end
  end

  def prepare_cities(datetime, day, in_dev) do
    City.list_active_cities_preload(datetime, in_dev)
    # |> Enum.filter(fn city -> if in_dev, do: true, else: Date.diff(city.last_login, datetime) > -30 end)
    # |> Enum.filter(fn city ->
    #   city.huts > 5 || city.single_family_homes > 0 || city.apartments > 0 ||
    #     city.homeless_shelters > 0 || city.micro_apartments > 0 || city.high_rises > 0 ||
    #     city.megablocks > 0
    # end)
    |> Enum.map(fn city ->
      Map.put(city, :citizens_blob, city.citizens_compressed |> Citizens.unfold_citizen_blob(day, city.id))
    end)
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
