defmodule MayorGame.CityTest do
  use MayorGame.DataCase
  import MayorGame.Fixtures
  alias MayorGame.City
  alias MayorGame.City.{Buildable, Town}

  describe "create_town/1" do
    test "starts a city with money, tax rates and a few buildings" do
      user = user_fixture()

      assert {:ok, %Town{} = town} =
               City.create_town(%{title: "Springfield", region: "lake", climate: "arctic", user_id: user.id})

      town = Repo.get!(Town, town.id)
      assert town.treasury == 10_000
      assert town.huts == 5
      assert town.coal_plants == 1
      assert town.schools == 0
      assert map_size(town.tax_rates) == 6
    end

    test "requires a valid region" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               City.create_town(%{title: "Nowhere", region: "moon", climate: "arctic", user_id: user.id})
    end
  end

  describe "purchase_buildable/4" do
    test "buys a building and pays for it" do
      town = town_fixture(%{treasury: 1_000})

      assert {1, nil} = City.purchase_buildable(town, :parks, 300, nil)

      town = Repo.get!(Town, town.id)
      assert town.treasury == 700
      assert town.parks == 1
    end

    test "pays building resources too" do
      town = town_fixture(%{treasury: 1_000, wood: 15})

      assert {1, nil} = City.purchase_buildable(town, :single_family_homes, 100, %{wood: 10})

      town = Repo.get!(Town, town.id)
      assert {town.treasury, town.wood, town.single_family_homes} == {900, 5, 1}
    end

    test "refuses when the city can't afford it, even if its data is stale" do
      town = town_fixture(%{treasury: 1_000})
      # the city spends its money elsewhere after `town` was loaded
      Repo.update_all(from(t in Town, where: t.id == ^town.id), set: [treasury: 100])

      assert {:error, :cannot_afford} = City.purchase_buildable(town, :parks, 300, nil)
      assert {:error, :cannot_afford} = City.purchase_buildable(town, :single_family_homes, 50, %{wood: 10})
      assert Repo.get!(Town, town.id).treasury == 100
    end
  end

  describe "demolish_buildable/4" do
    test "removes a building and refunds half its price" do
      town = town_fixture(%{treasury: 0, parks: 2})
      price = Buildable.buildables_flat()[:parks].price

      assert {1, nil} = City.demolish_buildable(town, {%{}, 0}, :parks, 2)

      town = Repo.get!(Town, town.id)
      assert town.parks == 1
      assert town.treasury == round(MayorGame.Rules.building_price(price, 1) / 2)
    end

    test "does nothing when there's nothing left to demolish" do
      town = town_fixture(%{parks: 0})
      assert {:error, :nothing_to_demolish} = City.demolish_buildable(town, {%{}, 0}, :parks, 1)
    end
  end
end
