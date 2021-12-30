defmodule MayorGame.CityTest do
  use MayorGame.DataCase

  alias MayorGame.City

  describe "cities" do
    alias MayorGame.City.Town

    @valid_attrs %{region: "some region", title: "some title"}
    @update_attrs %{region: "some updated region", title: "some updated title"}
    @invalid_attrs %{region: nil, title: nil}

    def town_fixture(attrs \\ %{}) do
      {:ok, town} =
        attrs
        |> Enum.into(@valid_attrs)
        |> City.create_town()

      town
    end

    test "list_cities/0 returns all cities" do
      town = town_fixture()
      assert City.list_cities() == [town]
    end

    test "get_town!/1 returns the town with given id" do
      town = town_fixture()
      assert City.get_town!(town.id) == town
    end

    test "create_town/1 with valid data creates a town" do
      assert {:ok, %Town{} = town} = City.create_town(@valid_attrs)
      assert town.region == "some region"
      assert town.title == "some title"
    end

    test "create_town/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = City.create_town(@invalid_attrs)
    end

    test "update_town/2 with valid data updates the town" do
      town = town_fixture()
      assert {:ok, %Town{} = town} = City.update_town(town, @update_attrs)
      assert town.region == "some updated region"
      assert town.title == "some updated title"
    end

    test "update_town/2 with invalid data returns error changeset" do
      town = town_fixture()
      assert {:error, %Ecto.Changeset{}} = City.update_town(town, @invalid_attrs)
      assert town == City.get_town!(town.id)
    end

    test "delete_town/1 deletes the town" do
      town = town_fixture()
      assert {:ok, %Town{}} = City.delete_town(town)
      assert_raise Ecto.NoResultsError, fn -> City.get_town!(town.id) end
    end

    test "change_town/1 returns a town changeset" do
      town = town_fixture()
      assert %Ecto.Changeset{} = City.change_town(town)
    end
  end

  describe "citizens" do
    alias MayorGame.City.Citizens

    @valid_attrs %{money: 42, name: "some name"}
    @update_attrs %{money: 43, name: "some updated name"}
    @invalid_attrs %{money: nil, name: nil}

    def citizens_fixture(attrs \\ %{}) do
      {:ok, citizens} =
        attrs
        |> Enum.into(@valid_attrs)
        |> City.create_citizens()

      citizens
    end

    test "list_citizens/0 returns all citizens" do
      citizens = citizens_fixture()
      assert City.list_citizens() == [citizens]
    end

    test "get_citizens!/1 returns the citizens with given id" do
      citizens = citizens_fixture()
      assert City.get_citizens!(citizens.id) == citizens
    end

    test "create_citizens/1 with valid data creates a citizens" do
      assert {:ok, %Citizens{} = citizens} = City.create_citizens(@valid_attrs)
      assert citizens.money == 42
      assert citizens.name == "some name"
    end

    test "create_citizens/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = City.create_citizens(@invalid_attrs)
    end

    test "update_citizens/2 with valid data updates the citizens" do
      citizens = citizens_fixture()
      assert {:ok, %Citizens{} = citizens} = City.update_citizens(citizens, @update_attrs)
      assert citizens.money == 43
      assert citizens.name == "some updated name"
    end

    test "update_citizens/2 with invalid data returns error changeset" do
      citizens = citizens_fixture()
      assert {:error, %Ecto.Changeset{}} = City.update_citizens(citizens, @invalid_attrs)
      assert citizens == City.get_citizens!(citizens.id)
    end

    test "delete_citizens/1 deletes the citizens" do
      citizens = citizens_fixture()
      assert {:ok, %Citizens{}} = City.delete_citizens(citizens)
      assert_raise Ecto.NoResultsError, fn -> City.get_citizens!(citizens.id) end
    end

    test "change_citizens/1 returns a citizens changeset" do
      citizens = citizens_fixture()
      assert %Ecto.Changeset{} = City.change_citizens(citizens)
    end
  end

  describe "details" do
    alias MayorGame.City.Details

    @valid_attrs %{single_family_homes: 42, roads: 42, schools: 42}
    @update_attrs %{single_family_homes: 43, roads: 43, schools: 43}
    @invalid_attrs %{single_family_homes: nil, roads: nil, schools: nil}

    def details_fixture(attrs \\ %{}) do
      {:ok, details} =
        attrs
        |> Enum.into(@valid_attrs)
        |> City.create_details()

      details
    end

    test "list_details/0 returns all details" do
      details = details_fixture()
      assert City.list_details() == [details]
    end

    test "get_details!/1 returns the details with given id" do
      details = details_fixture()
      assert City.get_details!(details.id) == details
    end

    test "create_details/1 with valid data creates a details" do
      assert {:ok, %Details{} = details} = City.create_details(@valid_attrs)
      assert details.single_family_homes == 42
      assert details.roads == 42
      assert details.schools == 42
    end

    test "create_details/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = City.create_details(@invalid_attrs)
    end

    test "update_details/2 with valid data updates the details" do
      details = details_fixture()
      assert {:ok, %Details{} = details} = City.update_details(details, @update_attrs)
      assert details.single_family_homes == 43
      assert details.roads == 43
      assert details.schools == 43
    end

    test "update_details/2 with invalid data returns error changeset" do
      details = details_fixture()
      assert {:error, %Ecto.Changeset{}} = City.update_details(details, @invalid_attrs)
      assert details == City.get_details!(details.id)
    end

    test "delete_details/1 deletes the details" do
      details = details_fixture()
      assert {:ok, %Details{}} = City.delete_details(details)
      assert_raise Ecto.NoResultsError, fn -> City.get_details!(details.id) end
    end

    test "change_details/1 returns a details changeset" do
      details = details_fixture()
      assert %Ecto.Changeset{} = City.change_details(details)
    end
  end
end
