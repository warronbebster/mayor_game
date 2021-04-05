defmodule MayorGame.CityCalculator do
  use GenServer, restart: :permanent
  alias MayorGame.City
  alias MayorGame.City.Details

  def start_link(initial_val) do
    # starts link based on this file
    # which triggers init function in module
    # do a check to see if World exists, and if so, send world.day

    GenServer.start_link(__MODULE__, initial_val)
  end

  def init(initial_val) do
    # initial_val is 0 here, set in application.ex then started with start_link

    # send message :tax to self process after 5000ms
    Process.send_after(self(), :tax, 5000)

    # returns ok tuple when u start
    {:ok, initial_val}
  end

  # when tick is sent
  def handle_info(:tax, val) do
    cities = City.list_cities_preload()
    world = MayorGame.Repo.get!(MayorGame.City.World, 1)
    City.update_world(world, %{day: world.day + 1})
    IO.puts("day: " <> to_string(world.day) <> "——————————————————————————————————————————————")

    # result is map %{cities_w_room: [], citizens_looking: []}
    leftovers =
      Enum.reduce(cities, %{cities_w_room: [], citizens_looking: []}, fn city, acc ->
        # result here is %{jobs: #, housing: #, tax: #, money: #, citizens_looking: []}
        city_stats = calculate_city_stats(city)
        city_calc = calculate_stats_based_on_citizens(city.citizens, city_stats, world.day)

        # should i loop through citizens here, instead of in calculate_city_stats?
        # that way I can use the same function later?

        updated_city_treasury =
          if city_calc.money.available_money + city_calc.tax < 0,
            do: 0,
            else: city_calc.money.available_money + city_calc.tax

        # check here for if tax_income - money is less than zero
        case City.update_details(city.detail, %{city_treasury: updated_city_treasury}) do
          {:ok, _updated_details} ->
            City.update_log(
              city,
              "tax income: " <>
                to_string(city_calc.tax) <> " operating cost: " <> to_string(city_calc.money.cost)
            )

          {:error, err} ->
            IO.inspect(err)
        end

        # if city has leftover jobs
        are_there_jobs = Enum.any?(city_calc.jobs, fn {_level, number} -> number > 0 end)

        %{
          cities_w_room:
            if(city_calc.housing > 0 && are_there_jobs,
              do: [Map.put(city_calc, :city, city) | acc.cities_w_room],
              else: acc.cities_w_room
            ),
          citizens_looking: city_calc.citizens_looking ++ acc.citizens_looking
        }
      end)

    # SECOND ROUND CHECK (move citizens to better city, etc) here
    # if there are cities with room at all:
    if List.first(leftovers.cities_w_room) != nil do
      # for each citizen
      Enum.reduce(leftovers.citizens_looking, leftovers.cities_w_room, fn citizen,
                                                                          acc_city_list ->
        # results are map %{best_city: %{city: city, jobs: #, housing: #, etc}, job_level: #}
        best_job = find_best_job(acc_city_list, citizen)

        if not is_nil(best_job) do
          # move citizen to city
          move_citizen(citizen, best_job.best_city.city, world.day)

          # find where the city is in the list
          indexx = Enum.find_index(acc_city_list, &(&1.city == best_job.best_city.city))

          # make updated list, decrement housing and jobs
          updated_acc_city_list =
            List.update_at(acc_city_list, indexx, fn update ->
              update
              |> Map.update!(:housing, &(&1 - 1))
              |> update_in([:jobs, best_job.job_level], &(&1 - 1))
            end)

          updated_acc_city_list
        else
          # check here if city citizen wants to move from has housing or not
          kill_citizen(citizen)
          acc_city_list
        end
      end)
    else
      Enum.map(leftovers.citizens_looking, fn citizen ->
        kill_citizen(citizen)
      end)
    end

    # send val to liveView process that manages frontEnd; this basically sends to every client.
    MayorGameWeb.Endpoint.broadcast!(
      "cityPubSub",
      "ping",
      val
    )

    # recurse, do it again
    Process.send_after(self(), :tax, 5000)
    {:noreply, world.day + 1}
  end

  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW
  # CUSTOM HELPER FUNCTIONS BELOW

  def move_citizen(
        %MayorGame.City.Citizens{} = citizen,
        %MayorGame.City.Info{} = city_to_move_to,
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

  def kill_citizen(%MayorGame.City.Citizens{} = citizen) do
    City.update_log(City.get_info!(citizen.info_id), citizen.name <> " has died. RIP")
    City.delete_citizens(citizen)
  end

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
  def find_best_job(cities_to_check, %MayorGame.City.Citizens{} = citizen) do
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
    takes a %MayorGame.City.Info{} struct
    result here is %{jobs: #, housing: #, tax: #, money: #, citizens_looking: []}
  """
  def calculate_city_stats(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)

    area = calculate_area(city_preloaded)
    energy = calculate_energy(city_preloaded)
    money = calculate_money(city_preloaded)

    disabled_buildings =
      area.disabled_buildings ++ energy.disabled_buildings ++ money.disabled_buildings

    # but jobs and stuff aren't
    total_housing = calculate_housing(city_preloaded, disabled_buildings)
    # returns a map of %{0 => #, 0 => #, etc}
    total_jobs = calculate_jobs(city_preloaded, disabled_buildings)
    # returns a map of %{0 => #, 0 => #, etc}
    total_education = calculate_education(city_preloaded, disabled_buildings)

    %{
      city: city,
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
  def calculate_stats_based_on_citizens(citizens, city_stats, day) do
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
                (job_gap > 1 && citizen.last_moved + 365 < day) ||
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
              if rem(day, 365) == 0 && acc.education[citizen.education + 1] > 0 do
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

  returns transit & area info in map %{sprawl: int, total_area: int, disabled_buildings: [] available_area: int}
  """
  def calculate_area(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)

    preliminary_results =
      Enum.reduce(Details.buildables().transit, %{sprawl: 0, total_area: 0}, fn {transit_type,
                                                                                 transit_options},
                                                                                acc ->
        sprawl =
          acc.sprawl + transit_options.sprawl * Map.get(city_preloaded.detail, transit_type)

        area =
          acc.total_area +
            transit_options.area * Map.get(city_preloaded.detail, transit_type)

        %{sprawl: sprawl, total_area: area}
      end)

    area_results =
      Enum.reduce(
        MayorGame.City.Details.buildables(),
        %{disabled_buildings: [], area_left: preliminary_results.total_area},
        fn category, acc ->
          {_categoryName, buildings} = category

          Enum.reduce(
            buildings,
            %{
              disabled_buildings: acc.disabled_buildings,
              area_left: acc.area_left
            },
            fn {building_type, building_options}, acc2 ->
              building_count = Map.get(city_preloaded.detail, building_type)

              if Map.has_key?(building_options, :area_required) && building_count > 0 do
                Enum.reduce(
                  1..building_count,
                  %{
                    disabled_buildings: acc2.disabled_buildings,
                    area_left: acc2.area_left
                  },
                  fn _building, acc3 ->
                    negative_area = acc3.area_left < building_options.area_required

                    %{
                      disabled_buildings:
                        if(negative_area,
                          do: [building_type | acc3.disabled_buildings],
                          else: acc3.disabled_buildings
                        ),
                      area_left: acc3.area_left - building_options.area_required
                    }
                  end
                )
              else
                acc2
              end
            end
          )
        end
      )

    preliminary_results
    |> Map.put_new(:available_area, area_results.area_left)
    |> Map.put_new(:disabled_buildings, area_results.disabled_buildings)
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns energy info in map %{total_energy: int, available_energy: int, disabled_buildings: [], pollution: int}
  """
  def calculate_energy(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)

    # for each building in the energy category
    preliminary_results =
      Enum.reduce(Details.buildables().energy, %{total_energy: 0, pollution: 0}, fn {energy_type,
                                                                                     energy_options},
                                                                                    acc ->
        # region checking and multipliers
        region_energy_multiplier =
          if Map.has_key?(energy_options.region_energy_multipliers, city_preloaded.region),
            do: energy_options.region_energy_multipliers[city_preloaded.region],
            else: 1

        pollution =
          acc.pollution + energy_options.pollution * Map.get(city_preloaded.detail, energy_type)

        energy =
          acc.total_energy +
            energy_options.energy * Map.get(city_preloaded.detail, energy_type) *
              region_energy_multiplier

        %{total_energy: round(energy), pollution: pollution}
      end)

    energy_results =
      Enum.reduce(
        MayorGame.City.Details.buildables(),
        %{disabled_buildings: [], energy_left: preliminary_results.total_energy},
        fn category, acc ->
          {_categoryName, buildings} = category

          Enum.reduce(
            buildings,
            %{
              disabled_buildings: acc.disabled_buildings,
              energy_left: acc.energy_left
            },
            fn {building_type, building_options}, acc2 ->
              building_count = Map.get(city_preloaded.detail, building_type)

              if Map.has_key?(building_options, :energy_required) && building_count > 0 do
                Enum.reduce(
                  1..building_count,
                  %{
                    disabled_buildings: acc2.disabled_buildings,
                    energy_left: acc2.energy_left
                  },
                  fn _building, acc3 ->
                    negative_energy = acc3.energy_left < building_options.energy_required

                    %{
                      disabled_buildings:
                        if(negative_energy,
                          do: [building_type | acc3.disabled_buildings],
                          else: acc3.disabled_buildings
                        ),
                      energy_left: acc3.energy_left - building_options.energy_required
                    }
                  end
                )
              else
                acc2
              end
            end
          )
        end
      )

    preliminary_results
    |> Map.put_new(:available_energy, energy_results.energy_left)
    |> Map.put_new(:disabled_buildings, energy_results.disabled_buildings)
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns energy info in map %{amount: int, disabled_buildings: []}
  """
  def calculate_housing(%MayorGame.City.Info{} = city, disabled_buildings) do
    city_preloaded = preload_city_check(city)

    results =
      Enum.reduce(
        Details.buildables().housing,
        %{amount: 0, disabled_buildings: disabled_buildings},
        fn {building_type, building_options}, acc ->
          # get fits, multiply by number of buildings

          building_count = Map.get(city_preloaded.detail, building_type)

          if building_count > 0 do
            Enum.reduce(
              1..building_count,
              %{
                amount: acc.amount,
                disabled_buildings: acc.disabled_buildings
              },
              fn _building, acc2 ->
                if Enum.member?(disabled_buildings, building_type) do
                  %{
                    amount: acc2.amount,
                    disabled_buildings: acc2.disabled_buildings -- [building_type]
                  }
                else
                  %{
                    amount: acc2.amount + building_options.fits,
                    disabled_buildings: acc2.disabled_buildings
                  }
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
  takes a %MayorGame.City.Info{} struct, and a list[] of disabled buildings in atom form

  returns map of available jobs by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_jobs(%MayorGame.City.Info{} = city, disabled_buildings) do
    city_preloaded = preload_city_check(city)
    empty_jobs_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    results =
      Enum.reduce(
        Details.buildables(),
        %{jobs_map: empty_jobs_map, disabled_buildings: disabled_buildings},
        fn category, acc ->
          {categoryName, buildings} = category

          if categoryName != :housing && categoryName != :civic do
            job_map_results =
              Enum.map(acc.jobs_map, fn {job_level, jobs} ->
                results =
                  Enum.reduce(
                    buildings,
                    %{job_amount: 0, disabled_buildings: acc.disabled_buildings},
                    fn {building_type, building_options}, acc2 ->
                      if building_options.job_level == job_level do
                        building_count = Map.get(city_preloaded.detail, building_type)

                        if building_count > 0 do
                          Enum.reduce(
                            1..building_count,
                            %{
                              job_amount: acc2.job_amount,
                              disabled_buildings: acc2.disabled_buildings
                            },
                            fn _building, acc3 ->
                              if Enum.member?(disabled_buildings, building_type) do
                                %{
                                  job_amount: acc3.job_amount,
                                  disabled_buildings: acc3.disabled_buildings -- [building_type]
                                }
                              else
                                %{
                                  job_amount: acc3.job_amount + building_options.jobs,
                                  disabled_buildings: acc3.disabled_buildings
                                }
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
              jobs_map: Enum.into(job_map_results, %{}),
              disabled_buildings: acc.disabled_buildings
            }
          else
            acc
          end
        end
      )

    results.jobs_map
  end

  @doc """
  takes a %MayorGame.City.Info{} struct, and a list[] of disabled buildings in atom form

  returns map of available education by level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}
  """
  def calculate_education(%MayorGame.City.Info{} = city, disabled_buildings) do
    city_preloaded = preload_city_check(city)
    empty_education_map = %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}

    # results =
    #   Enum.reduce(
    #     Details.buildables(),
    #     %{education_map: empty_education_map, disabled_buildings: disabled_buildings},
    #     fn category, acc ->
    #       {categoryName, buildings} = category

    # if categoryName == :education do
    education_map_results =
      Enum.map(empty_education_map, fn {education_level, capacity} ->
        results =
          Enum.reduce(
            Details.buildables().education,
            %{education_amount: 0, disabled_buildings: disabled_buildings},
            fn {building_type, building_options}, acc2 ->
              if building_options.education_level == education_level do
                building_count = Map.get(city_preloaded.detail, building_type)

                if building_count > 0 do
                  Enum.reduce(
                    1..building_count,
                    %{
                      education_amount: acc2.education_amount,
                      disabled_buildings: acc2.disabled_buildings
                    },
                    fn _building, acc3 ->
                      if Enum.member?(disabled_buildings, building_type) do
                        %{
                          education_amount: acc3.education_amount,
                          disabled_buildings: acc3.disabled_buildings -- [building_type]
                        }
                      else
                        %{
                          education_amount: acc3.education_amount + building_options.capacity,
                          disabled_buildings: acc3.disabled_buildings
                        }
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

    # # return this
    # %{
    # education_map: Enum.into(education_map_results, %{}),
    #   disabled_buildings: acc.disabled_buildings
    # }
    # else
    #   acc
    # end
    # end
    # )

    # results.education_map
    Enum.into(education_map_results, %{})
  end

  @doc """
  takes a %MayorGame.City.Info{} struct

  returns building cost info in map %{available_money: int, disabled_buildings: [], cost: int}
  """
  def calculate_money(%MayorGame.City.Info{} = city) do
    city_preloaded = preload_city_check(city)

    preliminary_results = city.detail.city_treasury

    cost_results =
      Enum.reduce(
        MayorGame.City.Details.buildables(),
        %{disabled_buildings: [], money_left: preliminary_results, cost: 0},
        fn category, acc ->
          {_categoryName, buildings} = category

          Enum.reduce(
            buildings,
            %{
              disabled_buildings: acc.disabled_buildings,
              money_left: acc.money_left,
              cost: acc.cost
            },
            fn {building_type, building_options}, acc2 ->
              building_count = Map.get(city_preloaded.detail, building_type)

              if Map.has_key?(building_options, :daily_cost) &&
                   building_count > 0 &&
                   building_options[:daily_cost] > 0 do
                Enum.reduce(
                  1..building_count,
                  %{
                    disabled_buildings: acc2.disabled_buildings,
                    money_left: acc2.money_left,
                    cost: acc2.cost
                  },
                  fn _building, acc3 ->
                    negative_money = acc3.money_left < building_options.daily_cost

                    %{
                      disabled_buildings:
                        if(negative_money,
                          do: [building_type | acc3.disabled_buildings],
                          else: acc3.disabled_buildings
                        ),
                      money_left: acc3.money_left - building_options.daily_cost,
                      cost: acc3.cost + building_options.daily_cost
                    }
                  end
                )
              else
                acc2
              end
            end
          )
        end
      )

    %{
      available_money: cost_results.money_left,
      disabled_buildings: cost_results.disabled_buildings,
      cost: cost_results.cost
    }
  end

  def preload_city_check(%MayorGame.City.Info{} = city) do
    if !Ecto.assoc_loaded?(city.detail) do
      city |> MayorGame.Repo.preload([:citizens, :user, :detail])
    else
      city
    end
  end
end
