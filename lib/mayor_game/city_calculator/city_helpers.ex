defmodule MayorGame.CityHelpers do
  alias MayorGame.City
  alias MayorGame.City.{Citizens, Town, Buildable, Details, CombinedBuildable, World}

  @doc """
    takes a %Town{} struct and %World{} struct

    returns a map:
    ```
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
    ```
  """
  def calculate_city_stats(%Town{} = city, %World{} = world) do
    city_preloaded = preload_city_check(city)

    # reset buildables status in database
    # this might end up being redundant because I can construct that status and not check it from the DB
    reset_buildables_to_enabled(city_preloaded)

    # ayyy this is successfully combining the buildables
    # next step is applying the upgrades (done)
    # and putting it in city_preloaded
    city_baked_details = %{city_preloaded | detail: bake_details(city_preloaded.detail)}

    # TODO-CLEAN BELOW UP
    # these basically take a city and then calculate total resource
    # and then also available resource
    # the energy and money ones seem not to check the enabled status of the buildings that generate
    # maybe they should?
    # if not these could probably all be combined
    city_updated =
      city_baked_details
      |> calculate_area()
      |> calculate_energy(world)
      |> calculate_money()

    # I think the following can all be calculated in the same function?
    total_housing = calculate_housing(city_updated)
    # returns a map of %{0 => #, 1 => #, etc}
    total_jobs = calculate_jobs(city_updated)
    # returns a map of %{0 => #, 1 => #, etc}
    total_education = calculate_education(city_updated)

    # return city

    Map.merge(city_updated, %{
      jobs: total_jobs,
      education: total_education,
      tax: 0,
      housing: total_housing,
      citizens_looking: []
    })
  end

  @doc """
  moves a given %Citizen{} into a given %Town{}, also takes a `day_moved`
  """
  def move_citizen(
        %Citizens{} = citizen,
        %Town{} = city_to_move_to,
        day_moved
      ) do
    prev_city = City.get_town!(citizen.town_id)

    if prev_city.id != city_to_move_to.id do
      City.update_log(
        prev_city,
        citizen.name <> " moved to " <> city_to_move_to.title
      )

      City.update_log(
        city_to_move_to,
        citizen.name <> " just moved here from " <> prev_city.title
      )

      City.update_citizens(citizen, %{town_id: city_to_move_to.id, last_moved: day_moved})
    end
  end

  def kill_citizen(%Citizens{} = citizen, deathReason) do
    City.update_log(
      City.get_town!(citizen.town_id),
      citizen.name <> " has died because of " <> deathReason <> ". RIP"
    )

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
      %{best_city: %{city: %Town{} struct, jobs: #, housing: #, tax: #, cost: #, etc}, job_level: level_to_check}
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
    takes a city_with_stats map, %World, and count of cities in ecosystem

    result here is a city with additional fields:
    ```
    jobs: integer,
    housing: integer,
    tax: integer,
    money: integer,
    citizens_looking: []}
    ```


  """
  def calculate_stats_based_on_citizens(city_with_stats, world, cities_count) do
    unless Enum.empty?(city_with_stats.citizens) do
      results =
        Enum.reduce(
          city_with_stats.citizens,
          city_with_stats,
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
                  town_id: citizen.town_id,
                  age: 0,
                  education: 0,
                  has_car: false,
                  last_moved: 0
                })

            # kill citizen
            # also kill based on roads / random chance
            if citizen.age > 36500, do: kill_citizen(citizen, "old age")

            # set a random pollution ceiling based on how many cities are in the ecosystem
            pollution_ceiling = :rand.uniform(cities_count * 10000) + 1000

            if world.pollution > pollution_ceiling do
              IO.puts(
                "pollution too high: " <>
                  to_string(world.pollution) <> " above ceiling: " <> to_string(pollution_ceiling)
              )

              kill_citizen(citizen, "pollution is too high")
            end

            # return city
            acc
            |> Map.put(:housing, acc.housing - 1)
            |> Map.put(:jobs, updated_jobs)
            |> Map.put(:education, updated_education)
            |> Map.put(:citizens_looking, citizens_looking)
            |> Map.put(
              :tax,
              round((1 + best_possible_job) * 100 * acc.tax_rates[to_string(citizen.education)]) +
                acc.tax
            )
          end
        )

      results
    else
      # if city has no citizens
      city_with_stats
    end
  end

  @doc """
  takes a %MayorGame.City.Town{} struct

  resets all buildables in DB to default enabled (e.g. working, not purchasable)
  useful at the end/beginning of a cycle
  """

  def reset_buildables_to_enabled(%Town{} = city) do
    city_preloaded = preload_city_check(city)

    for buildable_type <- Buildable.buildables_list() do
      buildables = Map.get(city_preloaded.detail, buildable_type)

      if length(buildables) > 0 do
        for building <- buildables do
          City.update_buildable(city.detail, buildable_type, building.id, %{
            enabled: true,
            reason: []
          })
        end
      end
    end
  end

  @spec calculate_area(MayorGame.City.Town.t()) :: map
  @doc """
  takes a %MayorGame.City.Town{} struct

  returns %Town{} struct with additional fields:
  sprawl: int,
  total_area: int,
  available_area: int
  """
  def calculate_area(%Town{} = city) do
    # city_preloaded = preload_city_check(city)

    # see how much area is in the town, based on the transit buildables
    preliminary_results =
      Enum.reduce(Buildable.buildables().transit, %{sprawl: 0, total_area: 0}, fn {transit_type,
                                                                                   _transit_options},
                                                                                  acc ->
        %{
          sprawl: acc.sprawl + sum_detail_metadata(Map.get(city.detail, transit_type), :sprawl),
          total_area:
            acc.total_area +
              sum_detail_metadata(Map.get(city.detail, transit_type), :area)
        }
      end)

    # this really is only to calculate the disabled buildings; if you just wanted the totals, you could use the above
    area_results =
      Enum.reduce(
        Buildable.buildables_flat(),
        # accumulator:
        %{available_area: preliminary_results.total_area, city: city},
        fn {buildable_type, buildable_options}, acc ->
          # get list of each type of buildables
          buildable_list = Map.get(city.detail, buildable_type)

          if buildable_options.area_required != nil && length(buildable_list) > 0 do
            # for each individual buildable in the list
            buildable_list_results =
              Enum.reduce(
                buildable_list,
                %{available_area: acc.available_area, buildable_list_updated_reasons: []},
                fn individual_buildable, acc2 ->
                  negative_area =
                    acc2.available_area < individual_buildable.metadata.area_required

                  updated_buildable =
                    if negative_area do
                      # update buildable in DB to enabled: false
                      # this touches DB: bad
                      # this should just touch the %Buildable{} in the CombinedBuildable
                      City.update_buildable(
                        city.detail,
                        buildable_type,
                        individual_buildable.buildable.id,
                        %{
                          enabled: false,
                          reason:
                            cond do
                              Enum.empty?(individual_buildable.buildable.reason) ->
                                ["area"]

                              Enum.member?(individual_buildable.buildable.reason, "area") ->
                                individual_buildable.buildable.reason

                              true ->
                                ["area" | individual_buildable.buildable.reason]
                            end
                        }
                      )

                      put_in(individual_buildable, [:buildable, :reason], ["area"])
                    else
                      individual_buildable
                    end

                  %{
                    available_area:
                      acc2.available_area - individual_buildable.metadata.area_required,
                    buildable_list_updated_reasons:
                      Enum.concat(acc2.buildable_list_updated_reasons, [updated_buildable])
                    # TODO maybe: make this a | list combine and reverse whole list outside enum
                  }
                end
              )

            # if there have been updates
            city_update =
              if buildable_list_results.buildable_list_updated_reasons !=
                   Map.get(city.detail, buildable_type) do
                Map.put(
                  city,
                  [:detail, buildable_type],
                  buildable_list_results.buildable_list_updated_reasons
                )
              else
                city
              end

            %{
              available_area: buildable_list_results.available_area,
              city: city_update
              # TODO maybe: make this a | list combine and reverse whole list outside enum
            }
          else
            # if there are no buildables of that type or they don't require area
            acc
          end
        end
      )

    results_map = Map.merge(preliminary_results, %{available_area: area_results.available_area})

    # return city
    Map.merge(area_results.city, results_map)
  end

  @spec calculate_energy(map, World.t()) :: map
  @doc """
  takes a %MayorGame.City.Town{} struct

  returns %Town{} struct with additional fields added:
  pollution: int,
  total_energy: int,
  available_energy: int
  """
  def calculate_energy(%Town{} = city, world) do
    # city_preloaded = preload_city_check(city)

    # for each building in the energy category
    preliminary_results =
      Enum.reduce(
        Buildable.buildables().energy,
        %{total_energy: 0, pollution: 0},
        fn {energy_type, energy_options}, acc ->
          # region checking and multipliers
          region_energy_multiplier =
            if Map.has_key?(
                 energy_options.region_energy_multipliers,
                 String.to_existing_atom(city.region)
               ),
               do: energy_options.region_energy_multipliers[String.to_existing_atom(city.region)],
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
              sum_detail_metadata(Map.get(city.detail, energy_type), :pollution)

          energy =
            acc.total_energy +
              sum_detail_metadata(Map.get(city.detail, energy_type), :energy) *
                region_energy_multiplier * season_energy_multiplier

          %{total_energy: round(energy), pollution: pollution}
        end
      )

    energy_results =
      Enum.reduce(
        Buildable.buildables_flat(),
        %{available_energy: preliminary_results.total_energy, city: city},
        fn {buildable_type, buildable_options}, acc ->
          # get list of each type of buildables
          buildable_list = Map.get(city.detail, buildable_type)

          if buildable_options.energy_required != nil && length(buildable_list) > 0 do
            # for each individual buildable in the list
            buildable_list_results =
              Enum.reduce(
                buildable_list,
                %{available_energy: acc.available_energy, buildable_list_updated_reasons: []},
                fn individual_buildable, acc2 ->
                  negative_energy =
                    acc2.available_energy < individual_buildable.metadata.energy_required

                  updated_buildable =
                    if negative_energy do
                      City.update_buildable(
                        city.detail,
                        buildable_type,
                        individual_buildable.buildable.id,
                        %{
                          enabled: false,
                          # TODO: clean this shit up
                          reason:
                            cond do
                              Enum.empty?(individual_buildable.buildable.reason) ->
                                ["energy"]

                              Enum.member?(individual_buildable.buildable.reason, "energy") ->
                                individual_buildable.buildable.reason

                              true ->
                                ["energy" | individual_buildable.buildable.reason]
                            end
                        }
                      )

                      put_in(individual_buildable, [:buildable, :reason], [
                        "energy" | individual_buildable.buildable.reason
                      ])
                    else
                      individual_buildable
                    end

                  %{
                    available_energy:
                      acc2.available_energy - individual_buildable.metadata.energy_required,
                    buildable_list_updated_reasons:
                      Enum.concat(acc2.buildable_list_updated_reasons, [updated_buildable])
                    # TODO maybe: make this a | list combine and reverse whole list outside enum
                  }
                end
              )

            # if there have been updates
            city_update =
              if buildable_list_results.buildable_list_updated_reasons !=
                   Map.get(city.detail, buildable_type) do
                Map.put(
                  city,
                  [:detail, buildable_type],
                  buildable_list_results.buildable_list_updated_reasons
                )
              else
                city
              end

            %{
              available_energy: buildable_list_results.available_energy,
              city: city_update
            }
          else
            # if there are no buildables of that type or they don't require energy
            acc
          end
        end
      )

    results_map =
      Map.merge(preliminary_results, %{available_energy: energy_results.available_energy})

    # return city
    Map.merge(energy_results.city, results_map)
  end

  @spec calculate_money(map) :: map
  @doc """
  takes a %MayorGame.City.Town{} struct

  returns %Town{} struct with additional fields added:
  cost: int,
  available_money: int,
  """
  def calculate_money(%Town{} = city) do
    # city_preloaded = preload_city_check(city)

    # how much money the city currently has
    preliminary_results = city.detail.city_treasury

    money_results =
      Enum.reduce(
        Buildable.buildables_flat(),
        %{available_money: preliminary_results, cost: 0, city: city},
        fn {buildable_type, buildable_options}, acc ->
          # get list of each type of buildables
          buildables_list = Map.get(city.detail, buildable_type)

          # if Map.has_key?(buildable_options, :daily_cost) &&
          if buildable_options.daily_cost != nil &&
               length(buildables_list) > 0 &&
               buildable_options.daily_cost > 0 do
            buildable_list_results =
              Enum.reduce(
                buildables_list,
                %{
                  available_money: acc.available_money,
                  cost: acc.cost,
                  buildable_list_updated_reasons: []
                },
                fn individual_buildable, acc3 ->
                  negative_money = acc3.available_money < individual_buildable.metadata.daily_cost

                  updated_buildable =
                    if negative_money do
                      City.update_buildable(
                        city.detail,
                        buildable_type,
                        individual_buildable.buildable.id,
                        %{
                          enabled: false,
                          # if there's already a reason it's disabled
                          reason:
                            cond do
                              Enum.empty?(individual_buildable.buildable.reason) ->
                                ["money"]

                              Enum.member?(individual_buildable.reason, "money") ->
                                individual_buildable.buildable.reason

                              true ->
                                ["money" | individual_buildable.buildable.reason]
                            end
                        }
                      )

                      put_in(individual_buildable, [:buildable, :reason], [
                        "money" | individual_buildable.buildable.reason
                      ])
                    else
                      individual_buildable
                    end

                  %{
                    available_money:
                      acc3.available_money - individual_buildable.metadata.daily_cost,
                    cost: acc3.cost + individual_buildable.metadata.daily_cost,
                    buildable_list_updated_reasons:
                      Enum.concat(acc3.buildable_list_updated_reasons, [updated_buildable])
                    # TODO maybe: make this a | list combine and reverse whole list outside enum
                  }
                end
              )

            # if there have been updates
            city_update =
              if buildable_list_results.buildable_list_updated_reasons !=
                   Map.get(city.detail, buildable_type) do
                Map.put(
                  city,
                  [:detail, buildable_type],
                  buildable_list_results.buildable_list_updated_reasons
                )
              else
                city
              end

            %{
              available_money: buildable_list_results.available_money,
              cost: buildable_list_results.cost,
              city: city_update
            }
          else
            # if there are no buildables of that type or they don't require energy
            acc
          end
        end
      )

    results_map = %{
      available_money: money_results.available_money,
      cost: money_results.cost
    }

    # return city
    Map.merge(money_results.city, results_map)
  end

  @doc """
  takes a %MayorGame.City.Town{} struct

  returns energy town in map %{amount: int}
  """
  def calculate_housing(%Town{} = city) do
    # city_preloaded = preload_city_check(city)

    results =
      Enum.reduce(
        Buildable.buildables().housing,
        %{amount: 0},
        fn {buildable_type, _buildable_options}, acc ->
          # grab the actual buildables from the city
          buildables = Map.get(city.detail, buildable_type)

          if length(buildables) > 0 do
            Enum.reduce(
              buildables,
              %{amount: acc.amount},
              fn building, acc2 ->
                if !building.buildable.enabled do
                  %{amount: acc2.amount}
                else
                  # increment by the amount it fits
                  %{amount: acc2.amount + building.metadata.fits}
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
  takes a %MayorGame.City.Town{} struct

  returns map of available jobs by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_jobs(%Town{} = city) do
    # city_preloaded = preload_city_check(city)
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
                    fn {buildable_type, buildable_options}, acc2 ->
                      if buildable_options.job_level == job_level do
                        buildables = Map.get(city.detail, buildable_type)

                        if length(buildables) > 0 do
                          Enum.reduce(
                            buildables,
                            %{job_amount: acc2.job_amount},
                            fn building, acc3 ->
                              if !building.buildable.enabled do
                                %{job_amount: acc3.job_amount}
                              else
                                %{job_amount: acc3.job_amount + building.metadata.jobs}
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
  takes a %MayorGame.City.Town{} struct

  returns map of available education by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_education(%Town{} = city) do
    # city_preloaded = preload_city_check(city)
    empty_education_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    Enum.map(empty_education_map, fn {education_level, capacity} ->
      results =
        Enum.reduce(
          Buildable.buildables().education,
          %{education_amount: 0},
          fn {buildable_type, buildable_options}, acc2 ->
            if buildable_options.education_level == education_level do
              buildables = Map.get(city.detail, buildable_type)

              if length(buildables) > 0 do
                Enum.reduce(
                  buildables,
                  %{education_amount: acc2.education_amount},
                  fn building, acc3 ->
                    if !building.buildable.enabled do
                      %{education_amount: acc3.education_amount}
                    else
                      %{education_amount: acc3.education_amount + building.metadata.capacity}
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

  @spec preload_city_check(Town.t()) :: Town.t()
  @doc """
      Take a %Town{}, return the %Town{} with citizens, user, detail preloaded
  """
  def preload_city_check(%Town{} = town) do
    if !Ecto.assoc_loaded?(town.detail) do
      town |> MayorGame.Repo.preload([:citizens, :user, detail: Buildable.buildables_list()])
    else
      town
    end
  end

  @spec preload_city_check(Details.t()) :: Details.t()
  @doc """
      Takes a %Details{} struct

      returns the %Details{} with each buildable listing %CombinedBuildable{}s instead of raw %Buildable{}s
  """
  def bake_details(%Details{} = detail) do
    Enum.reduce(Buildable.buildables_list(), detail, fn buildable_list_item, details_struct_acc ->
      has_buildable = Enum.empty?(Map.get(details_struct_acc, buildable_list_item))

      if Map.has_key?(details_struct_acc, buildable_list_item) && !has_buildable do
        buildable_array = Map.get(details_struct_acc, buildable_list_item)

        buildable_metadata = Map.get(Buildable.buildables_flat(), buildable_list_item)

        combined_array =
          Enum.map(buildable_array, fn x ->
            CombinedBuildable.combine_and_apply_upgrades(x, buildable_metadata)
          end)

        %{details_struct_acc | buildable_list_item => combined_array}
      else
        details_struct_acc
      end
    end)
  end

  # @spec sum_detail_metadata(list(BuildableMetadata.t()), atom) :: integer | float
  @doc """
      takes a list of CombinedBuildables (usually held by details) and returns the sum of the metadata
  """
  def sum_detail_metadata(baked_buildable_list, metadata_to_sum) do
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
   take a city, update the buildables inside's  purchasable status
  """
  def bake_city_purchasables(city_with_stats) do
    # Enum.map(Buildable.buildables_flat(), fn b_metadata_raw ->
    #   b_metadata_raw
    #    |> Enum.map(fn {buildable_key, buildable_stats} ->
    #      {buildable_key, Map.from_struct(calculate_buildable_status(buildable_stats, city))}
    #    end)}
    # end)

    detail_results =
      Enum.reduce(Buildable.buildables_list(), city_with_stats.detail, fn b_type,
                                                                          details_struct_acc ->
        # get a list of the buildables
        buildables_array = Map.get(details_struct_acc, b_type)
        # does the details have any of the b_type?
        # d_has_buildable = !Enum.empty?(buildables_array)

        # if Map.has_key?(details_struct_acc, buildable_list_item) && d_has_buildable do
        # b_metadata_baked = Map.get(city_with_stats.detail, b_type)

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

    %{city_with_stats | detail: detail_results}
  end

  # TODO: clean this shit up
  def bake_purchasable_status(buildable, city_with_stats) do
    if city_with_stats.detail.city_treasury > buildable.metadata.price do
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
          |> put_in([:metadata, :purchasable_reason], "not enough area to build")

        # not enough energy AND not enough area
        buildable.metadata.energy_required != nil and
          city_with_stats.available_energy < buildable.metadata.energy_required &&
            (buildable.metadata.area_required != nil and
               city_with_stats.available_area < buildable.metadata.area_required) ->
          buildable
          |> put_in([:metadata, :purchasable], false)
          |> put_in([:metadata, :purchasable_reason], "not enough area or energy to build")

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
          |> put_in([:metadata, :purchasable_reason], "not enough area to build")

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
          |> put_in([:metadata, :purchasable_reason], "not enough energy to build")

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
      |> put_in([:metadata, :purchasable_reason], "not enough money to build")
    end
  end
end
