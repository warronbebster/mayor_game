defmodule MayorGame.CityCalculatorTest do
  use MayorGame.DataCase
  import MayorGame.Fixtures
  alias MayorGame.{City, CityCalculator}
  alias MayorGame.City.{Buildable, Citizens, OngoingAttacks, Town, World}

  defp state(world_id) do
    {:ok, state} = CityCalculator.init(world_id)
    state
  end

  defp citizens(town), do: Citizens.unfold_citizen_blob(town.citizens_compressed, 0, town.id)

  setup do
    :rand.seed(:exsss, {101, 102, 103})
    {:ok, world} = City.create_world(%{day: 2_000, pollution: 0})
    %{world: world}
  end

  test "a tick advances the world by a day and broadcasts it", %{world: world} do
    MayorGameWeb.Endpoint.subscribe("cityPubSub")
    for _ <- 1..5, do: random_town_fixture(world.day)

    updated_world = CityCalculator.run_tick(state(world.id))

    assert updated_world.day == world.day + 1
    assert Repo.get!(World, world.id).day == world.day + 1
    assert_receive %{event: "ping", payload: %World{day: day}} when day == world.day + 1
  end

  test "a tick keeps citizen counts in sync with the citizen blobs", %{world: world} do
    towns = for _ <- 1..12, do: random_town_fixture(world.day)
    before_total = towns |> Enum.map(&length(citizens(&1))) |> Enum.sum()

    CityCalculator.run_tick(state(world.id))

    towns = Enum.map(towns, &Repo.get!(Town, &1.id))
    after_total = towns |> Enum.map(&length(citizens(&1))) |> Enum.sum()

    for town <- towns, do: assert(town.citizen_count == length(citizens(town)))
    # citizens move, are born and die, but don't appear out of nowhere
    born = towns |> Enum.map(& &1.logs_births) |> Enum.sum()
    assert after_total <= before_total + born
  end

  test "a tick runs with no active cities", %{world: world} do
    assert %World{} = CityCalculator.run_tick(state(world.id))
  end

  test "inactive cities are left alone", %{world: world} do
    town = random_town_fixture(world.day) |> Town.changeset(%{last_login: ~D[2000-01-01]}) |> Repo.update!()
    before = Repo.get!(Town, town.id)

    CityCalculator.run_tick(state(world.id))

    assert Repo.get!(Town, town.id) == before
  end

  test "ongoing attacks are resolved without crashing the tick", %{world: world} do
    attacker =
      random_town_fixture(world.day)
      |> Town.changeset(%{air_bases: 3, missiles: 500})
      |> Repo.update!()

    defender = town_fixture(%{shields: 2, retaliate: true})

    Repo.insert!(%OngoingAttacks{attacking_id: attacker.id, attacked_id: defender.id, attack_count: 50})

    assert %World{} = CityCalculator.run_tick(state(world.id))
  end

  test "buildables list matches the town schema" do
    for buildable <- Buildable.buildables_list(), do: assert(Map.has_key?(%Town{}, buildable))
  end
end
