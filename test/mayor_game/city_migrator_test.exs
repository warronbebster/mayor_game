defmodule MayorGame.CityMigratorTest do
  use MayorGame.DataCase
  import MayorGame.Fixtures
  alias MayorGame.{CityHelpers, CityMigrator, Rules}
  alias MayorGame.City.{Buildable, ResourceStats, World}

  # A city as CityMigrator.migrate/1 sees it: a town merged with its TownStats and TownMigrationStatistics.
  # Only the fields migration uses are set.
  defp city(id, opts \\ []) do
    {stats, opts} = Keyword.pop(opts, :stats, %{})
    {tax, opts} = Keyword.pop(opts, :tax, 0.1)

    %{
      id: id,
      housing_left: 0,
      vacancies_by_level: Map.new(0..5, &{&1, 0}),
      tax_rates: Map.new(0..5, &{to_string(&1), tax}),
      resource_stats:
        Map.new(
          [:sprawl, :pollution, :fun, :health, :culture, :crime],
          &{&1, %ResourceStats{title: to_string(&1), production: Map.get(stats, &1, 0), consumption: 0}}
        ),
      staying_citizens: [],
      migrating_citizens: [],
      migrating_citizens_due_to_tax: [],
      unemployed_citizens: [],
      unhoused_citizens: []
    }
    |> Map.merge(Map.new(opts))
  end

  defp citizen(town_id, education \\ 0),
    do: %{"town_id" => town_id, "education" => education, "preferences" => 1, "age" => 100}

  defp vacancies(level_counts), do: Map.merge(Map.new(0..5, &{&1, 0}), level_counts)

  defp count(result, id), do: length(result.citizens_by_id[id])

  test "unhoused citizens with nowhere to go die, and are counted" do
    result =
      CityMigrator.migrate([
        city(1, housing_left: -3, unhoused_citizens: [citizen(1), citizen(1), citizen(1)]),
        city(2)
      ])

    assert count(result, 1) == 0
    assert count(result, 2) == 0
    assert result.unhoused_deaths == %{1 => 3}
  end

  test "unhoused citizens move to open housing elsewhere, and the rest die" do
    result =
      CityMigrator.migrate([
        city(1, housing_left: -3, unhoused_citizens: [citizen(1), citizen(1), citizen(1)]),
        city(2, housing_left: 2, stats: %{fun: 100})
      ])

    assert count(result, 2) == 2
    assert result.unhoused_deaths == %{1 => 1}
    assert result.housing == %{1 => %{0 => 2}}
  end

  test "employed citizens don't move for a city that's no better" do
    result =
      CityMigrator.migrate([
        city(1, migrating_citizens: [citizen(1)]),
        city(2, housing_left: 5, vacancies_by_level: vacancies(%{0 => 5}))
      ])

    assert count(result, 1) == 1
    assert result.tax == %{}
  end

  test "employed citizens move for a better city with a job and housing at their level" do
    result =
      CityMigrator.migrate([
        city(1, migrating_citizens: [citizen(1, 2)]),
        city(2, housing_left: 5, vacancies_by_level: vacancies(%{2 => 1}), stats: %{fun: 100, culture: 100})
      ])

    assert count(result, 2) == 1
    assert result.tax == %{1 => %{2 => 1}}
  end

  test "unemployed citizens never move into a city without an open slot" do
    # city 2's only slot is in city 2 itself, which its own unemployed citizen can't take
    result =
      CityMigrator.migrate([
        city(1),
        city(2, housing_left: 1, vacancies_by_level: vacancies(%{0 => 1}), unemployed_citizens: [citizen(2)])
      ])

    assert count(result, 1) == 0
    assert count(result, 2) == 1
    assert result.jobs == %{}
  end

  # every citizen going into migration comes out in a city, or counted as dead
  for seed <- 1..6 do
    test "no citizens are lost in a random world (seed #{seed})" do
      :rand.seed(:exsss, {unquote(seed), 7, 13})
      day = 1000 + :rand.uniform(20_000)
      world = %World{id: 1, day: day, pollution: :rand.uniform(4_000_000_000)}
      for _ <- 1..(5 + :rand.uniform(25)), do: random_town_fixture(day)

      cities = prepared_cities(world)

      in_count =
        cities
        |> Enum.flat_map(
          &(&1.staying_citizens ++
              &1.migrating_citizens ++
              &1.migrating_citizens_due_to_tax ++ &1.unemployed_citizens ++ &1.unhoused_citizens)
        )
        |> length()

      result = CityMigrator.migrate(cities)
      out_count = result.citizens_by_id |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
      deaths = result.unhoused_deaths |> Map.values() |> Enum.sum()

      assert in_count == out_count + deaths
    end
  end

  defp prepared_cities(world) do
    buildables_map = %{
      buildables_flat: Buildable.buildables_flat(),
      buildables_list: Buildable.buildables_list()
    }

    {:ok, now} = DateTime.now("Etc/UTC")
    season = Rules.season_from_day(world.day)

    CityHelpers.prepare_cities(now, world.day, false)
    |> Enum.map(fn city ->
      stats = CityHelpers.calculate_city_stats_with_drops(city, world, 1.0e10, season, buildables_map, false, false)
      migration = CityHelpers.calculate_citizen_stats(city, stats, world, 1.0e10, season, buildables_map, false, false)
      city |> Map.merge(stats) |> Map.merge(migration)
    end)
    |> Enum.shuffle()
  end
end
