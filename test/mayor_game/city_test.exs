defmodule MayorGame.CityTest do
  use MayorGame.DataCase

  alias MayorGame.City

  describe "cities" do
    alias MayorGame.City.Info

    @valid_attrs %{region: "some region", title: "some title"}
    @update_attrs %{region: "some updated region", title: "some updated title"}
    @invalid_attrs %{region: nil, title: nil}

    def info_fixture(attrs \\ %{}) do
      {:ok, info} =
        attrs
        |> Enum.into(@valid_attrs)
        |> City.create_info()

      info
    end

    test "list_cities/0 returns all cities" do
      info = info_fixture()
      assert City.list_cities() == [info]
    end

    test "get_info!/1 returns the info with given id" do
      info = info_fixture()
      assert City.get_info!(info.id) == info
    end

    test "create_info/1 with valid data creates a info" do
      assert {:ok, %Info{} = info} = City.create_info(@valid_attrs)
      assert info.region == "some region"
      assert info.title == "some title"
    end

    test "create_info/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = City.create_info(@invalid_attrs)
    end

    test "update_info/2 with valid data updates the info" do
      info = info_fixture()
      assert {:ok, %Info{} = info} = City.update_info(info, @update_attrs)
      assert info.region == "some updated region"
      assert info.title == "some updated title"
    end

    test "update_info/2 with invalid data returns error changeset" do
      info = info_fixture()
      assert {:error, %Ecto.Changeset{}} = City.update_info(info, @invalid_attrs)
      assert info == City.get_info!(info.id)
    end

    test "delete_info/1 deletes the info" do
      info = info_fixture()
      assert {:ok, %Info{}} = City.delete_info(info)
      assert_raise Ecto.NoResultsError, fn -> City.get_info!(info.id) end
    end

    test "change_info/1 returns a info changeset" do
      info = info_fixture()
      assert %Ecto.Changeset{} = City.change_info(info)
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

    @valid_attrs %{houses: 42, roads: 42, schools: 42}
    @update_attrs %{houses: 43, roads: 43, schools: 43}
    @invalid_attrs %{houses: nil, roads: nil, schools: nil}

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
      assert details.houses == 42
      assert details.roads == 42
      assert details.schools == 42
    end

    test "create_details/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = City.create_details(@invalid_attrs)
    end

    test "update_details/2 with valid data updates the details" do
      details = details_fixture()
      assert {:ok, %Details{} = details} = City.update_details(details, @update_attrs)
      assert details.houses == 43
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
