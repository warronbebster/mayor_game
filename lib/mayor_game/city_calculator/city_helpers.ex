defmodule MayorGame.CityHelpers do
  alias MayorGame.{City, Repo}
  alias MayorGame.City.{Citizens, Info, Buildable, World}

  @doc """
    takes a %MayorGame.City.Info{} struct
    result here is %{jobs: #, housing: #, tax: #, money: #, citizens_looking: []}
  """
  def calculate_city_stats(%Info{} = city, %World{} = world) do
    city_preloaded = preload_city_check(city)

    # reset buildables status in database
    reset_buildables_to_enabled(city_preloaded)
    # TODO-CLEAN BELOW UP
    # these basically take a city and then calculate total resource
    # and then also available resource
    # the energy and money ones seem not to check the enabled status of the buildings that generate
    # maybe they should?
    # if not these could probably all be combined
    area = calculate_area(city_preloaded)
    energy = calculate_energy(city_preloaded |> Repo.preload([:detail]), world)
    money = calculate_money(city_preloaded |> Repo.preload([:detail]))

    # I think the following can all be calculated in the same function?
    city_update = city_preloaded |> Repo.preload([:detail])
    # but jobs and stuff aren't
    total_housing = calculate_housing(city_update)
    # returns a map of %{0 => #, 0 => #, etc}
    total_jobs = calculate_jobs(city_update)
    # returns a map of %{0 => #, 0 => #, etc}
    total_education = calculate_education(city_update)

    %{
      city: city_update,
      jobs: total_jobs,
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
  end

  @doc """
  moves a given %Citizen{} into a given %Info{}, also takes a `day_moved`
  """
  def move_citizen(
        %Citizens{} = citizen,
        %Info{} = city_to_move_to,
        day_moved
      ) do
    prev_city = City.get_info!(citizen.info_id)

    if prev_city.id != city_to_move_to.id do
      City.update_log(
        prev_city,
        citizen.name <> " moved to " <> city_to_move_to.title
      )

      City.update_log(
        city_to_move_to,
        citizen.name <> " just moved here from " <> prev_city.title
      )

      City.update_citizens(citizen, %{info_id: city_to_move_to.id, last_moved: day_moved})
    end
  end

  def kill_citizen(%Citizens{} = citizen) do
    City.update_log(City.get_info!(citizen.info_id), citizen.name <> " has died. RIP")
    City.delete_citizens(citizen)
  end

  @spec find_cities_with_job(list(), integer()) :: list()
  @doc """
  tries to find a cities with matching job level. expects a list of city_calcs and a level to check.
  returns a list of city_calc maps if successful, otherwise nil

  ## Examples
      iex> find_cities_with_job(city_list, 2)
       [%{city: city, jobs: #, housing: #, etc}, %{city: city, jobs: #, housing: #, etc}]
  """
  def find_cities_with_job(cities, level) do
    Enum.filter(cities, fn city_to_check ->
      is_number(city_to_check.jobs[level]) &&
        city_to_check.jobs[level] > 0 &&
        city_to_check.housing > 0
    end)
  end

  @doc """
  tries to find city with best match for citizen job based on education level
  takes list of city_calc maps and a %Citizens{} struct
  returns either city_calc map or nil if no results

  ## Examples
      iex> find_best_job(city_list, %Citizens{})
      %{best_city: %{city: %Info{} struct, jobs: #, housing: #, tax: #, cost: #, etc}, job_level: level_to_check}
  """
  def find_best_job(cities_to_check, %Citizens{} = citizen) do
    # pseudo code
    # find all cities with jobs of best possible job_level
    # then for each city, get:
    # tax_rate for job_level
    # fun rating
    # sprawl rating
    # fun rating
    # pollution rating/health rating
    # then make decision

    results =
      if citizen.education > 0 do
        # [3,2,1,0]
        levels = Enum.reverse(0..citizen.education)

        Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
          cities_with_jobs = find_cities_with_job(cities_to_check, level_to_check)

          if List.first(cities_with_jobs) == nil,
            do: {:cont, job_acc - 1},
            else: {:halt, %{cities_with_jobs: cities_with_jobs, job_level: level_to_check}}
        end)
      else
        cities_with_jobs = find_cities_with_job(cities_to_check, 0)

        if List.first(cities_with_jobs) == nil,
          do: -1,
          else: %{cities_with_jobs: cities_with_jobs, job_level: 0}
      end

    if is_map(results) do
      scored_results =
        Enum.map(results.cities_with_jobs, fn city_calc ->
          # normalize pollution by dividing by energy
          # normalize sprawl by dividing by area
          # should probably do this when calculating it, not here

          score =
            city_calc.city.tax_rates[to_string(results.job_level)] *
              citizen.preferences["tax_rates"] +
              city_calc.pollution / city_calc.energy * citizen.preferences["pollution"] +
              city_calc.sprawl / city_calc.area * citizen.preferences["sprawl"]

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
    takes a list of citizens from a city, and a city_stats map:
    %{
      jobs: total_jobs,
      tax: 0,
      housing: total_housing,
      money: #,
      citizens_looking: []
    }
    result here is %{jobs: #, housing: #, tax: #, money: #, citizens_looking: []}
  """
  def calculate_stats_based_on_citizens(citizens, city_stats, world, cities_count) do
    if List.first(citizens) != nil do
      results =
        Enum.reduce(
          citizens,
          city_stats,
          fn citizen, acc ->
            City.update_citizens(citizen, %{age: citizen.age + 1})

            # if there are NO jobs for citizen, returns -1.
            best_possible_job =
              if citizen.education > 0 do
                # [3,2,1,0]
                levels = Enum.reverse(0..citizen.education)

                Enum.reduce_while(levels, citizen.education, fn level_to_check, job_acc ->
                  if acc.jobs[level_to_check] > 0,
                    do: {:halt, job_acc},
                    else: {:cont, job_acc - 1}
                end)
              else
                if acc.jobs[0] > 0, do: 0, else: -1
              end

            job_gap = citizen.education - best_possible_job

            # citizen will look if there is no housing, if there is no best possible job, or if gap > 1
            will_citizen_look =
              best_possible_job < 0 ||
                (job_gap > 1 && citizen.last_moved + 365 < world.day) ||
                acc.housing < 1

            # add to citizens_looking array
            citizens_looking =
              if will_citizen_look,
                do: [citizen | acc.citizens_looking],
                else: acc.citizens_looking

            updated_jobs =
              if best_possible_job > -1,
                do: Map.update!(acc.jobs, best_possible_job, &(&1 - 1)),
                else: acc.jobs

            # once a year

            updated_education =
              if rem(world.day, 365) == 0 && acc.education[citizen.education + 1] > 0 do
                IO.inspect(acc.education)
                City.update_citizens(citizen, %{education: citizen.education + 1})
                Map.update!(acc.education, citizen.education + 1, &(&1 - 1))
              else
                acc.education
              end

            # function to spawn children
            # function to look for education if have money
            # or just give education automatically if university exists?

            # spawn new citizens if conditions are right
            if citizen.age == 9125 && citizen.education > 1,
              do:
                City.create_citizens(%{
                  money: 0,
                  name: "child",
                  info_id: citizen.info_id,
                  age: 0,
                  education: 0,
                  has_car: false,
                  last_moved: 0
                })

            # kill citizen
            # also kill based on roads / random chance
            if citizen.age > 36500, do: kill_citizen(citizen)

            pollution_ceiling = :rand.uniform(cities_count * 100)

            if world.pollution > pollution_ceiling do
              IO.puts(
                "pollution too high: " <>
                  to_string(world.pollution) <> " above ceiling: " <> to_string(pollution_ceiling)
              )
            end

            # return this
            %{
              city: acc.city,
              jobs: updated_jobs,
              education: updated_education,
              tax:
                round(
                  (1 + best_possible_job) * 100 * acc.city.tax_rates[to_string(citizen.education)]
                ) +
                  acc.tax,
              housing: acc.housing - 1,
              money: acc.money,
              area: acc.area,
              sprawl: acc.sprawl,
              energy: acc.energy,
              pollution: acc.pollution,
              citizens_looking: citizens_looking
            }
          end
        )

      results
    else
      city_stats
    end
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  resets all buildables in DB to default enabled
  """

  def reset_buildables_to_enabled(%Info{} = city) do
    city_preloaded = preload_city_check(city)

    for building_type <- Buildable.buildables_list() do
      buildables = Map.get(city_preloaded.detail, building_type)

      if length(buildables) > 0 do
        for building <- buildables do
          City.update_buildable(city.detail, building_type, building.id, %{
            enabled: true,
            reason: []
          })
        end
      end
    end
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns transit & area info in map %{sprawl: int, total_area: int, available_area: int}
  """
  def calculate_area(%Info{} = city) do
    city_preloaded = preload_city_check(city)

    preliminary_results =
      Enum.reduce(Buildable.buildables().transit, %{sprawl: 0, total_area: 0}, fn {transit_type,
                                                                                   transit_options},
                                                                                  acc ->
        sprawl =
          acc.sprawl +
            transit_options.sprawl * length(Map.get(city_preloaded.detail, transit_type))

        area =
          acc.total_area +
            transit_options.area * length(Map.get(city_preloaded.detail, transit_type))

        %{sprawl: sprawl, total_area: area}
      end)

    # this really is only to calculate the disabled buildings; if you just wanted the totals, you could use the above
    area_results =
      Enum.reduce(
        Buildable.buildables(),
        %{area_left: preliminary_results.total_area},
        fn category, acc ->
          {_categoryName, buildings} = category

          Enum.reduce(buildings, %{area_left: acc.area_left}, fn {building_type, building_options},
                                                                 acc2 ->
            buildables = Map.get(city_preloaded.detail, building_type)

            if Map.has_key?(building_options, :area_required) && length(buildables) > 0 do
              Enum.reduce(buildables, %{area_left: acc2.area_left}, fn building, acc3 ->
                negative_area = acc3.area_left < building_options.area_required

                if negative_area do
                  # update buildable in DB to enabled: false
                  City.update_buildable(city.detail, building_type, building.id, %{
                    enabled: false,
                    reason: ["area"]
                  })
                end

                %{area_left: acc3.area_left - building_options.area_required}
              end)
            else
              acc2
            end
          end)
        end
      )

    preliminary_results
    |> Map.put_new(:available_area, area_results.area_left)
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns energy info in map %{total_energy: int, available_energy: int, pollution: int}
  total_energy is all energy generated, available_energy is after accounting for usage
  """
  def calculate_energy(%MayorGame.City.Info{} = city, world) do
    city_preloaded = preload_city_check(city)

    # for each building in the energy category
    preliminary_results =
      Enum.reduce(
        Buildable.buildables().energy,
        %{total_energy: 0, pollution: 0},
        fn {energy_type, energy_options}, acc ->
          # region checking and multipliers
          region_energy_multiplier =
            if Map.has_key?(energy_options.region_energy_multipliers, city_preloaded.region),
              do: energy_options.region_energy_multipliers[city_preloaded.region],
              else: 1

          season =
            cond do
              rem(world.day, 365) < 91 -> :winter
              rem(world.day, 365) < 182 -> :spring
              rem(world.day, 365) < 273 -> :summer
              true -> :fall
            end

          season_energy_multiplier =
            if Map.has_key?(energy_options.season_energy_multipliers, season),
              do: energy_options.season_energy_multipliers[season],
              else: 1

          pollution =
            acc.pollution +
              energy_options.pollution * length(Map.get(city_preloaded.detail, energy_type))

          energy =
            acc.total_energy +
              energy_options.energy * length(Map.get(city_preloaded.detail, energy_type)) *
                region_energy_multiplier * season_energy_multiplier

          %{total_energy: round(energy), pollution: pollution}
        end
      )

    energy_results =
      Enum.reduce(
        Buildable.buildables(),
        %{energy_left: preliminary_results.total_energy},
        fn category, acc ->
          {_categoryName, buildings} = category

          Enum.reduce(buildings, %{energy_left: acc.energy_left}, fn {building_type,
                                                                      building_options},
                                                                     acc2 ->
            buildables = Map.get(city_preloaded.detail, building_type)

            if Map.has_key?(building_options, :energy_required) && length(buildables) > 0 do
              Enum.reduce(buildables, %{energy_left: acc2.energy_left}, fn building, acc3 ->
                negative_energy = acc3.energy_left < building_options.energy_required

                if negative_energy do
                  City.update_buildable(city.detail, building_type, building.id, %{
                    enabled: false,
                    reason:
                      if(Enum.empty?(building.reason),
                        do: ["energy"],
                        else: ["energy" | building.reason]
                      )
                  })
                end

                %{energy_left: acc3.energy_left - building_options.energy_required}
              end)
            else
              acc2
            end
          end)
        end
      )

    preliminary_results
    |> Map.put_new(:available_energy, energy_results.energy_left)
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns building cost info in map %{available_money: int, cost: int}
  """
  def calculate_money(%Info{} = city) do
    city_preloaded = preload_city_check(city)

    # how much money the city currently has
    preliminary_results = city.detail.city_treasury

    cost_results =
      Enum.reduce(
        Buildable.buildables(),
        %{money_left: preliminary_results, cost: 0},
        fn category, acc ->
          {_categoryName, buildings} = category

          Enum.reduce(buildings, %{money_left: acc.money_left, cost: acc.cost}, fn {building_type,
                                                                                    building_options},
                                                                                   acc2 ->
            buildables = Map.get(city_preloaded.detail, building_type)

            if Map.has_key?(building_options, :daily_cost) &&
                 length(buildables) > 0 &&
                 building_options[:daily_cost] > 0 do
              Enum.reduce(
                buildables,
                %{money_left: acc2.money_left, cost: acc2.cost},
                fn building, acc3 ->
                  negative_money = acc3.money_left < building_options.daily_cost

                  if negative_money do
                    City.update_buildable(city.detail, building_type, building.id, %{
                      enabled: false,
                      # if there's already a reason it's disabled
                      reason:
                        if(Enum.empty?(building.reason),
                          do: ["money"],
                          else: ["money" | building.reason]
                        )
                    })
                  end

                  %{
                    money_left: acc3.money_left - building_options.daily_cost,
                    cost: acc3.cost + building_options.daily_cost
                  }
                end
              )
            else
              acc2
            end
          end)
        end
      )

    %{
      available_money: cost_results.money_left,
      cost: cost_results.cost
    }
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns energy info in map %{amount: int}
  """
  def calculate_housing(%Info{} = city) do
    city_preloaded = preload_city_check(city)

    results =
      Enum.reduce(
        Buildable.buildables().housing,
        %{amount: 0},
        fn {building_type, building_options}, acc ->
          buildables = Map.get(city_preloaded.detail, building_type)

          if length(buildables) > 0 do
            Enum.reduce(
              buildables,
              %{amount: acc.amount},
              fn building, acc2 ->
                if !building.enabled do
                  %{amount: acc2.amount}
                else
                  %{amount: acc2.amount + building_options.fits}
                end
              end
            )
          else
            acc
          end
        end
      )

    results.amount
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns map of available jobs by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_jobs(%Info{} = city) do
    city_preloaded = preload_city_check(city)
    empty_jobs_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    results =
      Enum.reduce(
        Buildable.buildables(),
        %{jobs_map: empty_jobs_map},
        fn category, acc ->
          {categoryName, buildings} = category

          if categoryName != :housing && categoryName != :civic do
            job_map_results =
              Enum.map(acc.jobs_map, fn {job_level, jobs} ->
                results =
                  Enum.reduce(
                    buildings,
                    %{job_amount: 0},
                    fn {building_type, building_options}, acc2 ->
                      if building_options.job_level == job_level do
                        buildables = Map.get(city_preloaded.detail, building_type)

                        if length(buildables) > 0 do
                          Enum.reduce(
                            buildables,
                            %{job_amount: acc2.job_amount},
                            fn building, acc3 ->
                              if !building.enabled do
                                %{job_amount: acc3.job_amount}
                              else
                                %{job_amount: acc3.job_amount + building_options.jobs}
                              end
                            end
                          )
                        else
                          acc2
                        end
                      else
                        acc2
                      end
                    end
                  )

                {job_level, jobs + results.job_amount}
              end)

            # return this
            %{
              jobs_map: Enum.into(job_map_results, %{})
            }
          else
            acc
          end
        end
      )

    results.jobs_map
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns map of available education by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_education(%Info{} = city) do
    city_preloaded = preload_city_check(city)
    empty_education_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    # results =
    #   Enum.reduce(
    #     Buildable.buildables(),
    #     %{education_map: empty_education_map},
    #     fn category, acc ->
    #       {categoryName, buildings} = category

    # if categoryName == :education do
    # education_map_results =
    Enum.map(empty_education_map, fn {education_level, capacity} ->
      results =
        Enum.reduce(
          Buildable.buildables().education,
          %{education_amount: 0},
          fn {building_type, building_options}, acc2 ->
            if building_options.education_level == education_level do
              buildables = Map.get(city_preloaded.detail, building_type)

              if length(buildables) > 0 do
                Enum.reduce(
                  buildables,
                  %{education_amount: acc2.education_amount},
                  fn building, acc3 ->
                    if !building.enabled do
                      %{education_amount: acc3.education_amount}
                    else
                      %{education_amount: acc3.education_amount + building_options.capacity}
                    end
                  end
                )
              else
                acc2
              end
            else
              acc2
            end
          end
        )

      {education_level, capacity + results.education_amount}
    end)
    |> Enum.into(%{})
  end

  def preload_city_check(%Info{} = city) do
    if !Ecto.assoc_loaded?(city.detail) do
      city |> MayorGame.Repo.preload([:citizens, :user, detail: Buildable.buildables_list()])

      # MayorGame.Repo.preload(street: [city: [region: :country]])
    else
      city
    end
  end

  def reload_city(%Info{} = city) do
    city |> MayorGame.Repo.preload([:citizens, :user, detail: Buildable.buildables_list()])
  end
end
