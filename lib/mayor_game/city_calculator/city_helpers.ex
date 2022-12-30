defmodule MayorGame.CityHelpers do
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
  def calculate_city_stats(%Town{} = city, %World{} = world) do
    city_preloaded = preload_city_check(city)

    # reset buildables status in database
    # this might end up being redundant because I can construct that status and not check it from the DB
    city_reset = reset_buildables_to_enabled(city_preloaded)

    # ayyy this is successfully combining the buildables
    # next step is applying the upgrades (done)
    # and putting it in city_preloaded
    city_baked_details = %{city_reset | details: bake_details(city_reset.details)}

    # TODO-CLEAN BELOW UP
    # these basically take a city and then calculate total resource
    # and then also available resource
    # the energy and money ones seem not to check the enabled status of the buildings that generate
    # maybe they should?
    # if not these could probably all be combined
    city_updated =
      city_baked_details
      |> calculate_area()
      |> calculate_workers2()
      |> calculate_energy(world)
      |> calculate_money()

    # ok, calculate_workers2 nukes anything that requires a job, if there's no money airports, carbon capture, some others
    # …but only if there's no money?
    # yeah only if there's no money.

    # IO.inspect("updated from city_helpers", label: city.title)

    # I think the following can all be calculated in the same function?
    total_housing = calculate_housing(city_updated)
    # returns a map of %{0 => #, 1 => #, etc}
    total_workers = city_updated.workers_map

    # returns a map of %{0 => #, 1 => #, etc}
    total_education = calculate_education(city_updated)
    # returns a total num of fun
    total_fun = round(calculate_total_int(city_updated, :fun))
    total_health = round(calculate_total_int(city_updated, :health))

    # return city

    Map.merge(city_updated, %{
      workers: total_workers,
      education: total_education,
      housing: total_housing,
      fun: total_fun,
      health: total_health,
      # the below are initialized as empty to be filled later
      available_housing: total_housing,
      citizens_looking: [],
      citizens_out_of_room: [],
      citizens_too_old: [],
      citizens_polluted: [],
      citizens_to_reproduce: []
    })
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
        to_string(citizen.id) <> " moved to " <> city_to_move_to.title
      )

      City.update_log(
        city_to_move_to,
        to_string(citizen.id) <> " just moved here from " <> prev_city.title
      )

      City.update_citizens(citizen, %{town_id: city_to_move_to.id, last_moved: day_moved})
    end
  end

  def kill_citizen(%Citizens{} = citizen, deathReason) do
    City.update_log(
      City.get_town!(citizen.town_id),
      to_string(citizen.id) <> " has died because of " <> deathReason <> ". RIP"
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
        Enum.reduce(
          city_with_stats.citizens,
          city_with_stats,
          fn citizen, acc ->
            # see if I can just do this all at once instead of a DB write per loop
            # probably can't because it's a unique value per citizen
            # TODO see if
            City.update_citizens(citizen, %{age: citizen.age + 1})

            # set a random pollution ceiling based on how many cities are in the ecosystem
            # could try using :rand.normal here
            # could also use total citizens here
            Random.paretovariate(1)

            pollution_ceiling =
              cities_count * 1000_000 +
                1000_000 * Random.gammavariate(7.5, 1)

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
              if job_gap > 0 and citizen.last_moved + 100 < world.day,
                do: [citizen | acc.citizens_looking],
                else: acc.citizens_looking

            citizens_out_of_room =
              if acc.available_housing < 1,
                do: [citizen | acc.citizens_out_of_room],
                else: acc.citizens_out_of_room

            citizens_too_old =
              if citizen.age > 5000,
                do: [citizen | acc.citizens_too_old],
                else: acc.citizens_too_old

            citizens_polluted =
              if world.pollution > pollution_ceiling and citizen.age <= 5000,
                do: [citizen | acc.citizens_polluted],
                else: acc.citizens_polluted

            # spawn new citizens if conditions are right; age, random, housing exists
            citizens_to_reproduce =
              if citizen.age > 500 and citizen.age < 2000 and
                   :rand.uniform(length(city_with_stats.citizens) + 100) == 1,
                 do: [citizen | acc.citizens_to_reproduce],
                 else: acc.citizens_to_reproduce

            # once a year, update education of citizen if there is capacity
            # e.g. if the edu institutions have capacity
            # TODO: check here if there is a job of that level available?
            # otherwise citizens might just keep levelling up
            # oh i guess this is fine, they'll go to a lower job and start looking
            updated_education =
              if rem(world.day, 365) == 0 && citizen.education < 5 &&
                   acc.education[citizen.education + 1] > 0 do
                City.update_citizens(citizen, %{education: min(citizen.education + 1, 5)})

                City.update_log(
                  City.get_town!(citizen.town_id),
                  to_string(citizen.id) <>
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
            |> Map.put(:citizens_too_old, citizens_too_old)
            |> Map.put(:citizens_polluted, citizens_polluted)
            |> Map.put(:citizens_to_reproduce, citizens_to_reproduce)
          end
        )

      results
    else
      # if city has no citizens, just return
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

    # for buildable_type <- Buildable.buildables_list() do
    #   buildables = Map.get(city_preloaded.details, buildable_type)

    #   if length(buildables) > 0 do
    #     for building <- buildables do
    #       City.update_buildable(city.details, buildable_type, building.id, %{
    #         enabled: true,
    #         reason: []
    #       })
    #     end
    #   end
    # end

    cleared_details =
      Enum.reduce(
        Buildable.buildables_list(),
        city_preloaded.details,
        fn buildable_type, acc ->
          results =
            Enum.map(acc[buildable_type], fn buildable ->
              Map.put(buildable, :enabled, true)
              |> Map.put(:reason, [])
            end)

          Map.put(acc, buildable_type, results)
        end
      )

    #   Enum.map(city_preloaded.details, fn {_name, buildable_list} ->
    #     Enum.map(buildable_list, fn buildable ->
    #       Map.put(buildable, :enabled, true)city
    #       |> Map.put(:reason, [])
    #     end)
    #   end)

    Map.put(city_preloaded, :details, cleared_details)
  end

  @spec calculate_area(map) :: map
  @doc """
  takes a %MayorGame.City.Town{} struct

  returns %Town{} struct with additional fields:
  sprawl: int,
  total_area: int,
  available_area: int
  """
  def calculate_area(%{} = city) do
    # city_preloaded = preload_city_check(city)

    # see how much area is in the town, based on the transit buildables
    preliminary_results =
      Enum.reduce(Buildable.buildables().transit, %{sprawl: 0, total_area: 0}, fn {transit_type,
                                                                                   _transit_options},
                                                                                  acc ->
        buildables_list = Map.get(city.details, transit_type)

        # buildable_list_results =
        Enum.reduce(
          buildables_list,
          %{
            sprawl: acc.sprawl,
            total_area: acc.total_area
          },
          fn individual_buildable, acc2 ->
            if !individual_buildable.buildable.enabled do
              %{
                sprawl: acc2.sprawl,
                total_area: acc2.total_area
              }
            else
              %{
                sprawl: acc2.sprawl + individual_buildable.metadata.sprawl,
                total_area: acc2.total_area + individual_buildable.metadata.area
              }
            end
          end
        )

        # %{
        #   sprawl: acc.sprawl + sum_details_metadata(Map.get(city.details, transit_type), :sprawl),
        #   total_area:
        #     acc.total_area +
        #       sum_details_metadata(Map.get(city.details, transit_type), :area)
        # }
      end)

    # this really is only to calculate the disabled buildings; if you just wanted the totals, you could use the above
    area_results =
      Enum.reduce(
        Buildable.buildables_flat(),
        # accumulator:
        %{available_area: preliminary_results.total_area, city: city},
        fn {buildable_type, buildable_options}, acc ->
          # get list of each type of buildables
          buildable_list = Map.get(city.details, buildable_type)

          if buildable_options.area_required != nil && buildable_options.area_required != 0 &&
               length(buildable_list) > 0 do
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
                      put_reason_in_buildable(
                        acc.city,
                        buildable_type,
                        individual_buildable,
                        "area"
                      )

                      # City.update_buildable(
                      #   city.details,
                      #   buildable_type,
                      #   individual_buildable.buildable.id,
                      #   %{
                      #     enabled: false,
                      #     reason:
                      #       cond do
                      #         Enum.empty?(individual_buildable.buildable.reason) ->
                      #           ["area"]

                      #         Enum.member?(individual_buildable.buildable.reason, "area") ->
                      #           individual_buildable.buildable.reason

                      #         true ->
                      #           ["area" | individual_buildable.buildable.reason]
                      #       end
                      #   }
                      # )

                      # put_in(individual_buildable, [:buildable, :reason], ["area"])
                      # |> put_in([:buildable, :enabled], false)
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
              if buildable_list_results.buildable_list_updated_reasons !==
                   Map.get(city.details, buildable_type) do
                put_in(
                  city,
                  [:details, buildable_type],
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

          buildables_list = Map.get(city.details, energy_type)

          # return this
          Enum.reduce(
            buildables_list,
            %{
              pollution: acc.pollution,
              total_energy: acc.total_energy
            },
            fn individual_buildable, acc2 ->
              if !individual_buildable.buildable.enabled do
                %{
                  pollution: acc2.pollution,
                  total_energy: acc2.total_energy
                }
              else
                %{
                  pollution: acc2.pollution + individual_buildable.metadata.pollution,
                  total_energy:
                    acc2.total_energy +
                      round(
                        individual_buildable.metadata.energy *
                          region_energy_multiplier * season_energy_multiplier
                      )
                }
              end
            end
          )
        end
      )

    energy_results =
      Enum.reduce(
        Buildable.buildables_flat(),
        %{available_energy: preliminary_results.total_energy, city: city},
        fn {buildable_type, buildable_options}, acc ->
          # get list of each type of buildables
          buildable_list = Map.get(city.details, buildable_type)

          if buildable_options.energy_required != nil && length(buildable_list) > 0 do
            # for each individual buildable in the list
            buildable_list_results =
              Enum.reduce(
                buildable_list,
                %{available_energy: acc.available_energy, buildable_list_updated_reasons: []},
                fn individual_buildable, acc2 ->
                  # ok, airports and carbon capture aren't even making it here
                  # also universities, retail_shops

                  negative_energy =
                    acc2.available_energy < individual_buildable.metadata.energy_required

                  updated_buildable =
                    if negative_energy && individual_buildable.metadata.energy_required > 0 do
                      put_reason_in_buildable(
                        acc.city,
                        buildable_type,
                        individual_buildable,
                        "energy"
                      )
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
              if buildable_list_results.buildable_list_updated_reasons !==
                   Map.get(city.details, buildable_type) do
                put_in(
                  acc.city,
                  [:details, buildable_type],
                  buildable_list_results.buildable_list_updated_reasons
                )
              else
                acc.city
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
    Map.merge(Map.from_struct(energy_results.city), results_map)
  end

  @spec calculate_money(map) :: map
  @doc """
  takes a %MayorGame.City.Town{} struct

  returns %Town{} struct with additional fields added:
  cost: int,
  available_money: int,
  """
  def calculate_money(%{} = city) do
    # city_preloaded = preload_city_check(city)

    # how much money the city currently has
    preliminary_results = city.details.city_treasury

    money_results =
      Enum.reduce(
        Buildable.buildables_flat(),
        %{available_money: preliminary_results, cost: 0, city: city},
        fn {buildable_type, buildable_options}, acc ->
          # get list of each type of buildables
          buildable_list = Map.get(city.details, buildable_type)

          if buildable_options.money_required != nil &&
               length(buildable_list) > 0 &&
               buildable_options.money_required > 0 do
            buildable_list_results =
              Enum.reduce(
                buildable_list,
                %{
                  available_money: acc.available_money,
                  cost: acc.cost,
                  buildable_list_updated_reasons: []
                },
                fn individual_buildable, acc3 ->
                  negative_money = acc3.available_money < individual_buildable.metadata.money_required

                  updated_buildable =
                    if negative_money && individual_buildable.buildable.enabled do
                      put_reason_in_buildable(
                        acc.city,
                        buildable_type,
                        individual_buildable,
                        "money"
                      )
                    else
                      individual_buildable
                    end

                  updated_money =
                    if(individual_buildable.buildable.enabled,
                      do: acc3.available_money - individual_buildable.metadata.money_required,
                      else: acc3.available_money
                    )

                  updated_cost =
                    if(individual_buildable.buildable.enabled,
                      do: acc3.cost + individual_buildable.metadata.money_required,
                      else: acc3.cost
                    )

                  %{
                    available_money: updated_money,
                    cost: updated_cost,
                    buildable_list_updated_reasons:
                      Enum.concat(acc3.buildable_list_updated_reasons, [updated_buildable])
                    # TODO maybe: make this a | list combine and reverse whole list outside enum
                  }
                end
              )

            # if there have been updates
            city_update =
              if buildable_list_results.buildable_list_updated_reasons !==
                   Map.get(city.details, buildable_type) do
                put_in(
                  acc.city,
                  [:details, buildable_type],
                  buildable_list_results.buildable_list_updated_reasons
                )
              else
                acc.city
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

    # this is like the whole set of results, including the city

    results_map = %{
      available_money: money_results.available_money,
      cost: money_results.cost
    }

    # return city
    Map.merge(money_results.city, results_map)
  end

  @doc """
  takes a %MayorGame.City.Town{} struct

  returns total housing for town in map %{amount: int}
  """
  def calculate_housing(%{} = city) do
    # city_preloaded = preload_city_check(city)

    results =
      Enum.reduce(
        Buildable.buildables().housing,
        %{amount: 0},
        fn {buildable_type, _buildable_options}, acc ->
          # grab the actual buildables from the city
          buildables = Map.get(city.details, buildable_type)

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

  returns map of available workers by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_workers2(%{} = city) do
    # city_preloaded = preload_city_check(city)
    empty_workers_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
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

    sorted_buildables =
      Enum.filter(Buildable.buildables_flat(), fn {_name, metadata} ->
        metadata.job_level !== nil
      end)
      |> Enum.sort(&(elem(&1, 1).job_level > elem(&2, 1).job_level))

    results =
      Enum.reduce(
        sorted_buildables,
        %{
          workers_map: empty_workers_map,
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
              Enum.reduce(
                buildables_list,
                %{
                  total_workers: 0,
                  available_workers: 0,
                  tax: 0,
                  buildable_list_updated_reasons: [],
                  citizens: acc.citizens,
                  citizens_w_job_gap: acc.citizens_looking
                },
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
                      if individual_buildable.metadata.workers_required > 0 do
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
            workers_map:
              Map.put(
                acc.workers_map,
                job_level,
                acc.workers_map[job_level] + buildable_list_results.total_workers
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
      workers_map: results.workers_map,
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

  @doc """
  takes a %MayorGame.City.Town{} struct

  returns map of available education slots by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_education(%{} = city) do
    # city_preloaded = preload_city_check(city)
    empty_education_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    Enum.map(empty_education_map, fn {education_level, capacity} ->
      results =
        Enum.reduce(
          Buildable.buildables().education,
          %{education_amount: 0},
          fn {buildable_type, buildable_options}, acc2 ->
            if buildable_options.education_level == education_level do
              buildables = Map.get(city.details, buildable_type)

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

        updated_price = buildable_metadata.price * round(:math.pow(buildable_count, 2) + 1)

        buildable_metadata_price_updated = %MayorGame.City.BuildableMetadata{
          buildable_metadata
          | price: updated_price
        }

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

  defp put_reason_in_buildable(city, buildable_type, individual_buildable, reason) do
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
end
