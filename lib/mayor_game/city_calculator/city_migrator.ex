defmodule MayorGame.CityMigrator do
  @moduledoc """
  Moves citizens between cities. Runs once per game tick, called from `MayorGame.CityCalculator`.

  `migrate/1` is pure: it takes the tick's cities (each a `%Town{}` merged with its `TownStats` and
  `TownMigrationStatistics`, see `CityCalculator`) and decides where every citizen ends up.
  `persist/3` writes the result (citizen blobs, births, deaths, emigration logs) to the DB.

  Migration happens in rounds. Each round hands out the slots left over by the previous one:

    1. employed citizens who want to move (restless, or taxed too much) compete for
       job + housing slots at their education level. They only move if a city beats
       their current one by `@home_city_advantage`.
    2. unemployed citizens compete for the remaining job + housing slots at their level
    3. unhoused citizens compete for the remaining job + housing slots at their level
    4. unhoused citizens still without a slot take any open housing, at any level.
       Those who don't fit anywhere die (`logs_deaths_housing`).

  Within a round, citizens claim slots first-come-first-served, each picking the open
  city it scores highest (`citizen_score/3`).
  """
  alias MayorGame.City.{Citizens, Town, TownStats, ResourceStats}
  alias MayorGame.{CityHelpers, Repo}
  import Ecto.Query

  @home_city_advantage 0.05
  # levels are processed from most to least educated
  @levels 5..0//-1
  # citizen keys kept when a citizen moves; town_id is re-derived from the city they end up in
  @kept_citizen_keys ["education", "preferences", "age"]

  @type citizen :: %{String.t() => any}
  @type result :: %{
          citizens_by_id: %{integer => [citizen]},
          tax: %{integer => %{integer => integer}},
          jobs: %{integer => %{integer => integer}},
          housing: %{integer => %{integer => integer}},
          unhoused_deaths: %{integer => integer}
        }

  @doc """
  Decides where each citizen lives after this tick.

  Returns the new citizen list for every city, plus per-city emigration counts by education level
  (`tax`, `jobs`, `housing`: who left and why) and `unhoused_deaths`.
  """
  @spec migrate([map]) :: result
  def migrate(cities) do
    housing_slots = Map.new(cities, &{&1.id, &1.housing_left})
    normalized_cities_by_id = normalize_cities(cities)
    scores = preference_scores(normalized_cities_by_id)

    # citizens that aren't looking stay where they are
    citizens_by_id = Map.new(cities, &{&1.id, &1.staying_citizens})

    # round 1: employed citizens looking to move
    round_1 =
      cities
      |> Enum.flat_map(&(&1.migrating_citizens ++ &1.migrating_citizens_due_to_tax))
      |> level_round(job_and_housing_slots_by_level(housing_slots, normalized_cities_by_id), scores, :employed)

    # round 2: unemployed citizens, for the job slots left over from round 1
    round_2 =
      cities
      |> Enum.flat_map(& &1.unemployed_citizens)
      |> level_round(slots_left(round_1), scores, :other)

    # round 3: unhoused citizens, for the job slots left over from round 2
    round_3 =
      cities
      |> Enum.flat_map(& &1.unhoused_citizens)
      |> level_round(slots_left(round_2), scores, :other)

    citizens_by_id =
      citizens_by_id
      |> settle(round_1)
      |> return_home(left_out(round_1))
      |> settle(round_2)
      |> return_home(left_out(round_2))
      |> settle(round_3)

    housing_slots =
      housing_slots
      |> apply_moves(moves(round_1))
      |> apply_moves(moves(round_2))
      |> apply_moves(moves(round_3))

    # round 4: unhoused citizens who didn't get into round 3 look for housing anywhere
    {round_4_moves, citizens_by_id, unhoused_deaths} =
      housing_round(left_out(round_3), housing_slots, scores, citizens_by_id)

    %{
      citizens_by_id: citizens_by_id,
      tax: emigration_counts(moves(round_1)),
      jobs: emigration_counts(moves(round_2)),
      housing: emigration_counts(moves(round_3) ++ round_4_moves),
      unhoused_deaths: unhoused_deaths
    }
  end

  # ——————————————————————————————————————————————————————————————————————————————————
  # ROUNDS
  # ——————————————————————————————————————————————————————————————————————————————————

  # Per education level, citizens (in list order) each claim the best city that still has a
  # slot at their level. Only as many citizens as there are slots take part; the rest are `left_out`.
  # Returns %{level => %{choices: [{citizen, chosen_city_id}], slots: %{city_id => count}, left_out: [citizen]}}
  defp level_round(citizens, slots_by_level, scores, mode) do
    citizens_by_level = Enum.group_by(citizens, & &1["education"])

    Map.new(@levels, fn level ->
      slots = slots_by_level[level]

      {racing, left_out} =
        citizens_by_level
        |> Map.get(level, [])
        |> Enum.split(slots |> Map.values() |> Enum.sum())

      result =
        Enum.reduce(racing, %{choices: [], slots: slots}, fn citizen, acc ->
          chosen_id = choose_city(citizen, acc.slots, scores, mode)

          slots =
            if mode == :employed do
              # an employed citizen leaving frees up their old slot
              acc.slots |> Map.update(chosen_id, 0, &(&1 - 1)) |> Map.update(citizen["town_id"], 0, &(&1 + 1))
            else
              acc.slots |> Map.update(chosen_id, 0, &(&1 - 1))
            end

          %{choices: [{citizen, chosen_id} | acc.choices], slots: slots}
        end)

      {level, Map.put(result, :left_out, left_out)}
    end)
  end

  # :employed citizens may stay in (or pick) their own city, and only move for a meaningfully better one.
  # everyone else must pick a city other than their own.
  defp choose_city(citizen, slots, scores, mode) do
    town_id = citizen["town_id"]
    citizen_scores = scores[citizen["preferences"]][citizen["education"]]
    current_city_score = citizen_scores[town_id]

    chosen =
      Enum.reduce(slots, %{chosen_id: town_id, top_score: -1}, fn {city_id, count}, acc ->
        {score, beats_current?} =
          case mode do
            :employed ->
              score = if count > 0, do: citizen_scores[city_id], else: 0
              {score, score > current_city_score + @home_city_advantage}

            :other ->
              {if(count > 0 && city_id != town_id, do: citizen_scores[city_id], else: 0), true}
          end

        if score > acc.top_score && beats_current?, do: %{chosen_id: city_id, top_score: score}, else: acc
      end)

    chosen.chosen_id
  end

  # Unhoused citizens who didn't find a job slot take any city with open housing (if they like it more
  # than their current one). Citizens beyond the number of open housing slots die.
  defp housing_round(citizens, housing_slots, scores, citizens_by_id) do
    open_slots = housing_slots |> Enum.filter(fn {_id, count} -> count > 0 end) |> Map.new()

    {racing, dying} = Enum.split(citizens, housing_slots |> Map.values() |> Enum.sum())

    %{choices: choices} =
      Enum.reduce(racing, %{choices: [], slots: open_slots}, fn citizen, acc ->
        town_id = citizen["town_id"]
        citizen_scores = scores[citizen["preferences"]][citizen["education"]]

        chosen =
          Enum.reduce(acc.slots, %{chosen_id: town_id, top_score: citizen_scores[town_id]}, fn {city_id, count}, acc2 ->
            score = if count > 0, do: citizen_scores[city_id], else: 0
            if score > acc2.top_score, do: %{chosen_id: city_id, top_score: score}, else: acc2
          end)

        slots = acc.slots |> Map.update(chosen.chosen_id, 0, &(&1 - 1)) |> Map.update(town_id, 0, &(&1 + 1))

        %{choices: [{citizen, chosen.chosen_id} | acc.choices], slots: slots}
      end)

    round_moves = Enum.filter(choices, fn {citizen, chosen_id} -> citizen["town_id"] != chosen_id end)

    citizens_by_id =
      Enum.reduce(round_moves, citizens_by_id, fn {citizen, chosen_id}, acc ->
        Map.update!(acc, chosen_id, &[citizen | &1])
      end)

    {round_moves, citizens_by_id, Enum.frequencies_by(dying, & &1["town_id"])}
  end

  # ——————————————————————————————————————————————————————————————————————————————————
  # ROUND HELPERS
  # ——————————————————————————————————————————————————————————————————————————————————

  # Job + housing slots per education level: %{level => %{city_id => slot_count}}.
  # A city's housing is handed out to its vacancies from the lowest job level up.
  defp job_and_housing_slots_by_level(housing_slots, normalized_cities_by_id) do
    empty = Map.new(@levels, &{&1, %{}})

    Enum.reduce(housing_slots, empty, fn {city_id, housing_count}, acc ->
      slots_per_level =
        normalized_cities_by_id[city_id].jobs
        |> Enum.reduce(%{housing_slots_left: housing_count}, fn {level, count}, acc2 ->
          level_slots_count = if acc2.housing_slots_left > 0, do: min(count, acc2.housing_slots_left), else: 0

          acc2
          |> Map.update!(:housing_slots_left, &(&1 - level_slots_count))
          |> Map.put(level, level_slots_count)
        end)

      Map.new(@levels, fn level -> {level, Map.put(acc[level], city_id, Map.get(slots_per_level, level, 0))} end)
    end)
  end

  defp slots_left(round), do: Map.new(round, fn {level, %{slots: slots}} -> {level, slots} end)

  defp left_out(round), do: Enum.flat_map(@levels, &round[&1].left_out)

  # {citizen, chosen_city_id} for citizens who chose a city other than their own
  defp moves(round) do
    round
    |> Enum.flat_map(fn {_level, %{choices: choices}} -> choices end)
    |> Enum.filter(fn {citizen, chosen_id} -> citizen["town_id"] != chosen_id end)
  end

  # put each citizen of a round in the city they chose (which may be their own)
  defp settle(citizens_by_id, round) do
    Enum.reduce(@levels, citizens_by_id, fn level, acc ->
      Enum.reduce(round[level].choices, acc, fn {citizen, chosen_id}, acc2 ->
        Map.update!(acc2, chosen_id, &[Map.take(citizen, @kept_citizen_keys) | &1])
      end)
    end)
  end

  defp return_home(citizens_by_id, citizens) do
    Enum.reduce(citizens, citizens_by_id, fn citizen, acc ->
      Map.update!(acc, citizen["town_id"], &[Map.take(citizen, @kept_citizen_keys) | &1])
    end)
  end

  # movers free a housing slot in the city they left and take one in the city they join
  defp apply_moves(housing_slots, moves) do
    vacated = moves |> Enum.map(fn {citizen, _chosen_id} -> citizen["town_id"] end) |> Enum.frequencies()
    occupied = moves |> Enum.map(fn {_citizen, chosen_id} -> chosen_id end) |> Enum.frequencies()

    housing_slots
    |> Map.merge(vacated, fn _k, v1, v2 -> v1 + v2 end)
    |> Map.merge(occupied, fn _k, v1, v2 -> v1 - v2 end)
  end

  # %{origin_city_id => %{education_level => count}}
  defp emigration_counts(moves) do
    moves
    |> Enum.group_by(fn {citizen, _chosen_id} -> citizen["town_id"] end)
    |> Map.new(fn {city_id, city_moves} ->
      {city_id, Enum.frequencies_by(city_moves, fn {citizen, _} -> citizen["education"] end)}
    end)
  end

  # ——————————————————————————————————————————————————————————————————————————————————
  # SCORING
  # ——————————————————————————————————————————————————————————————————————————————————

  @doc """
  Normalizes each city's desirability stats against every other city's: %{city_id => normalized_city}
  """
  def normalize_cities(cities) do
    values = fn resource -> Enum.map(cities, &net_production(&1, resource)) end
    spread = fn resource -> Enum.max(values.(resource)) - Enum.min(values.(resource)) end

    divisors = %{
      sprawl: Enum.max(values.(:sprawl)),
      pollution: spread.(:pollution),
      fun: Enum.max(values.(:fun)),
      health: spread.(:health),
      culture: Enum.max(values.(:culture)),
      crime: Enum.max(values.(:crime))
    }

    Map.new(cities, &{&1.id, normalize_city(&1, divisors)})
  end

  defp normalize_city(city, divisors) do
    normalized = fn resource -> zero_check(net_production(city, resource), divisors[resource]) end

    %{
      city: city,
      jobs: city.vacancies_by_level,
      id: city.id,
      sprawl_normalized: normalized.(:sprawl),
      pollution_normalized: normalized.(:pollution),
      fun_normalized: normalized.(:fun),
      health_normalized: normalized.(:health),
      culture_normalized: normalized.(:culture),
      crime_normalized: normalized.(:crime),
      tax_rates: city.tax_rates
    }
  end

  defp net_production(city, resource), do: city |> TownStats.getResource(resource) |> ResourceStats.getNetProduction()

  defp zero_check(check, divisor) do
    if check == 0 or divisor == 0, do: 0, else: check / divisor
  end

  # %{preference_set => %{education_level => %{city_id => score}}}
  defp preference_scores(normalized_cities_by_id) do
    preset_preferences = Citizens.preset_preferences()

    Map.new(1..11, fn preference ->
      {preference,
       Map.new(0..5, fn edu_level ->
         {edu_level,
          Map.new(normalized_cities_by_id, fn {id, city} ->
            {id, Float.round(citizen_score(preset_preferences[preference], edu_level, city), 4)}
          end)}
       end)}
    end)
  end

  @doc """
  How much a citizen with the given preferences and education level would like to live in a normalized city.
  """
  def citizen_score(citizen_preferences, education_level, normalized_city) do
    # Clamp tax calculation preference between 0 & 1
    # Follows the following graph: https://www.desmos.com/calculator/69fewtjvma
    min(
      max(
        :math.pow(
          1 - normalized_city.tax_rates[to_string(education_level)],
          1.16 - citizen_preferences.tax_rates
        ),
        0
      ),
      1
    ) +
      (1 - normalized_city.pollution_normalized) * citizen_preferences.pollution +
      (1 - normalized_city.sprawl_normalized) * citizen_preferences.sprawl +
      normalized_city.fun_normalized * citizen_preferences.fun +
      normalized_city.health_normalized * citizen_preferences.health +
      normalized_city.culture_normalized * citizen_preferences.culture
  end

  # ——————————————————————————————————————————————————————————————————————————————————
  # PERSISTENCE
  # ——————————————————————————————————————————————————————————————————————————————————

  @doc """
  Writes the result of `migrate/1` to the DB, adding this tick's births.
  """
  @spec persist(result, [map], integer) :: :ok
  def persist(result, cities, day) do
    cities_by_id = Map.new(cities, &{&1.id, &1})

    result.citizens_by_id
    |> Enum.chunk_every(200)
    |> Enum.each(fn chunk ->
      Repo.checkout(
        fn -> Enum.each(chunk, fn {id, citizens} -> persist_city(cities_by_id[id], citizens, result, day) end) end,
        timeout: 6_000_000
      )
    end)
  end

  defp persist_city(city, citizens, result, day) do
    id = city.id

    births_count =
      if city.citizen_count > 20 do
        max(city.aggregate_births, 0)
      else
        # tiny cities get a random birth now and then so they can get going
        if :rand.uniform() > 0.5, do: 1, else: 0
      end

    newborns =
      if births_count > 0 do
        Enum.map(1..births_count, fn _ ->
          %{"age" => 0, "town_id" => id, "education" => 0, "preferences" => :rand.uniform(11)}
        end)
      else
        []
      end

    citizens = newborns ++ citizens

    from(t in Town,
      where: t.id == ^id,
      update: [
        set: [
          logs_emigration_taxes: ^add_counts(city.logs_emigration_taxes, result.tax[id]),
          logs_emigration_jobs: ^add_counts(city.logs_emigration_jobs, result.jobs[id]),
          logs_emigration_housing: ^add_counts(city.logs_emigration_housing, result.housing[id]),
          logs_edu: ^add_counts(city.logs_edu, city.educated_citizens),
          citizen_count: ^length(citizens),
          citizens_compressed: ^Citizens.compress_citizen_blob(citizens, day)
        ],
        inc: [
          logs_deaths_housing: ^Map.get(result.unhoused_deaths, id, 0),
          logs_deaths_pollution: ^city.aggregate_deaths_by_pollution,
          logs_deaths_starvation: ^city.aggregate_deaths_by_starvation,
          logs_deaths_age: ^city.aggregate_deaths_by_age,
          logs_births: ^births_count
        ]
      ]
    )
    |> Repo.update_all([])
  end

  # log maps come back from the DB with string keys
  defp add_counts(existing, nil), do: existing

  defp add_counts(existing, new_counts) do
    Map.merge(CityHelpers.integerize_keys(existing), new_counts, fn _k, v1, v2 -> v1 + v2 end)
  end
end
