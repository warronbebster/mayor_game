defmodule MayorGame.City do
  @moduledoc """
  The City context.
  """

  # THIS IS WHAT TALKS TO ECTO
  require Logger
  import Ecto.Query, warn: false
  alias MayorGame.Repo
  alias MayorGame.City.{Town, Citizens, World, Buildable}
  alias MayorGame.Rules

  @doc """
  Returns the list of cities.

  ## Examples

      iex> list_cities()
      [%Town{}, ...]

  """
  def list_cities do
    Repo.all(Town) |> Repo.preload([:user])
  end

  @doc """
  Returns the list of cities with preloads on the cities: preloads :citizens, :user, :details

  ## Examples

      iex> list_cities()
      [%Town{
        :citizens: [...],
        :user: %User{},
        :details: %details{

        }
      }, ...]

  """
  def list_cities_preload() do
    # TODO: can I filter here by last_login? that way I don't even have to do the filter in the server
    from(Town,
      select: ^Town.traits_minus_blob()
    )
    |> Repo.all(timeout: 800_000)
    |> Repo.preload(:user, timeout: 500_000)

    # Repo.all(Town, timeout: 800_000) |> Repo.preload([:user], timeout: 500_000)
  end

  @doc """
  Returns the list of cities with preloads on the cities: preloads :citizens, :user, :details

  ## Examples

      iex> list_cities()
      [%Town{
        :citizens: [...],
        :user: %User{},
        :details: %details{

        }
      }, ...]

  """
  def list_active_cities_preload(datetime, in_dev) do
    date_range = if in_dev, do: 2000, else: 30

    check_date = DateTime.add(datetime, -date_range, :day) |> DateTime.to_date()
    # TODO: can I filter here by last_login? that way I don't even have to do the filter in the server
    from(Town,
      select: ^Town.traits_minus_blob()
    )
    |> where([t], fragment("?::date", t.last_login) >= ^check_date)
    |> Repo.all(timeout: 800_000)
    |> Repo.preload(:user, timeout: 500_000)

    # Repo.all(Town, timeout: 800_000) |> Repo.preload([:user], timeout: 500_000)
  end

  @doc """
  Gets a single town.

  Raises `Ecto.NoResultsError` if the Town does not exist.

  ## Examples

      iex> get_town!(123)
      %Town{}

      iex> get_town!(456)
      ** (Ecto.NoResultsError)

  """
  def get_town!(id), do: Repo.get!(Town, id)

  def get_town_by_title!(title), do: Repo.get_by!(Town, title: title)

  @doc """
  Creates a town. which is a city

  ## Examples

      iex> create_town(%{field: value})
      {:ok, %Town{}}

      iex> create_town(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_town(attrs \\ %{}) do
    # have to create a resourcemap from scratch when creating a new town cuz it's required
    # TODO: remove this when creating cities from token

    buildables_zeroed =
      Enum.map(Buildable.buildables_ordered_flat(), fn k ->
        {k, 0}
      end)
      |> Enum.into(%{})

    intro_attrs =
      %{
        treasury: 10000,
        pollution: 0,
        citizen_count: 0,
        missiles: 0,
        shields: 0,
        gold: 0,
        sulfur: 0,
        uranium: 0,
        tax_rates: %{
          "0" => 0.1,
          "1" => 0.2,
          "2" => 0.3,
          "3" => 0.4,
          "4" => 0.5,
          "5" => 0.6
        }
      }
      |> Map.merge(buildables_zeroed)
      |> Map.merge(%{huts: 5, coal_plants: 1, roads: 1, gardens: 1})

    # make sure keys are atoms, helps with input from phoenix forms
    attrsWithAtomKeys =
      Map.new(attrs, fn {k, v} ->
        {if(!is_atom(k), do: String.to_existing_atom(k), else: k), v}
      end)
      |> Map.merge(intro_attrs)

    %Town{}
    |> Town.changeset(attrsWithAtomKeys)
    |> Repo.insert()
  end

  # hmm. I should probably figure out a way to make this return the city, not the details.
  # currently this returns the %Details struct
  def create_city(attrs \\ %{}) do
    case create_town(attrs) do
      # if city built successfully, automatically build Details with it's id
      # update this so these fields are automatically generated
      {:ok, created_city} ->
        {:ok, created_city}

      # IO.puts("city created!")

      # buildables = Map.new(Buildable.buildables_list(), fn buildable -> {buildable, []} end)

      # details = Map.merge(buildables, %{town_id: created_city.id})

      # # and create a detail in the DB, tied to this city
      # case create_details(details) do
      #   {:ok, _created_details} ->
      #     # return the city created
      #     {:ok, created_city}

      #   {:error, err} ->
      #     {:error, err}
      # end

      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  Updates a town.

  ## Examples

      iex> update_town(town, %{field: new_value})
      {:ok, %Town{}}

      iex> update_town(town, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_town(%Town{} = town, attrs) do
    town
    |> Town.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a town by ID, not by struct

  ## Examples

      iex> update_town_by_id(3, %{field: new_value})
      {:ok, %Town{}}

      iex> update_town_by_id(town, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_town_by_id(townId, attrs) do
    get_town!(townId)
    |> Town.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a town.

  ## Examples

      iex> delete_town(town)
      {:ok, %Town{}}

      iex> delete_town(town)
      {:error, %Ecto.Changeset{}}

  """
  def delete_town(%Town{} = town) do
    Repo.delete(town)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking town changes.

  ## Examples

      iex> change_town(town)
      %Ecto.Changeset{data: %Town{}}

  """
  def change_town(%Town{} = town, attrs \\ %{}) do
    Town.changeset(town, attrs)
  end

  @doc """
  Returns a tuple of changes from the repo

  """
  def add_citizens(%Town{} = town, day) do
    updated_compressed_citizens =
      town.citizens_compressed
      |> Map.merge(
        %{"100" => [%{"birthday" => Citizens.round100(day), "education" => 0, "preferences" => :rand.uniform(11)}]},
        fn _k, v1, v2 -> v1 ++ v2 end
      )

    from(t in Town,
      where: t.id == ^town.id,
      update: [
        set: [
          citizens_compressed: ^updated_compressed_citizens
        ]
      ]
    )
    |> Repo.update_all([])
  end

  # ###############################################
  # BUILDABLES
  # ###############################################

  @doc """
  purchase 1 of a given building
  expects (details, :atom of building, pric)

  ## Examples

      iex> purchase_buildable(details, :schools, 300)
      {:ok, %Details{}}

  """
  def purchase_buildable(%Town{} = city, field_to_purchase, purchase_price, building_reqs) do
    # city is unchanged, use the ledger to hold the accumlated construction and cost prior to UI refresh

    params =
      if is_nil(building_reqs) do
        %{treasury: city.treasury - purchase_price}
      else
        Enum.map(building_reqs, fn {req_key, req_value} ->
          {req_key, city[req_key] - req_value}
        end)
        |> Enum.into(%{treasury: city.treasury - purchase_price})
      end

    # ok this is working

    purchase_changeset =
      city
      |> Town.changeset(params)
      |> Ecto.Changeset.validate_number(:treasury, greater_than_or_equal_to: 0)

    purchase_changeset =
      if !is_nil(building_reqs) do
        Enum.reduce(building_reqs, purchase_changeset, fn {req_key, _req_value}, acc ->
          Ecto.Changeset.validate_number(acc, req_key, greater_than_or_equal_to: 0)
        end)
      else
        purchase_changeset
      end

    decrement =
      if is_nil(building_reqs) do
        [{field_to_purchase, 1}, {:treasury, -purchase_price}]
      else
        [{field_to_purchase, 1}, {:treasury, -purchase_price}] ++
          Enum.map(building_reqs, fn {req_key, req_value} -> {req_key, -req_value} end)
      end

    # map over

    if purchase_changeset.errors == [] do
      from(t in Town,
        where: [id: ^city.id]
      )
      |> Repo.update_all(inc: decrement)
    else
      Logger.error(inspect(purchase_changeset.errors))
      {:error, purchase_changeset.errors}
    end
  end

  @doc """
  remove 1 of a given building
  expects (details, :atom of building, building id)

  ## Examples

      iex> demolish_buildable(details, :schools, buildable_id int)
      {:ok, %Details{}}

  """
  def demolish_buildable(%Town{} = city, {_ledger_buildable, _ledger_cost}, buildable_to_demolish, buildable_count) do
    # city is unchanged, use the ledger to hold the accumlated construction and cost prior to UI refresh

    # buildable_pending =
    #   if !is_nil(ledger_buildable[buildable_to_demolish]) do
    #     ledger_buildable[buildable_to_demolish]
    #   else
    #     0
    #   end

    # city_attrs = %{buildable_to_demolish => city[buildable_to_demolish] + buildable_pending - 1}

    # refund_city =
    #   city
    #   |> Town.changeset(city_attrs)
    #   |> Ecto.Changeset.validate_number(buildable_to_demolish, greater_than_or_equal_to: 0)
    #   |> Repo.update()

    refund_price =
      round(
        Rules.building_price(
          Buildable.buildables_flat()[buildable_to_demolish].price,
          buildable_count - 1
        ) / 2
      )

    # case refund_city do
    #   {:ok, _result} ->
    from(t in Town,
      where: [id: ^city.id]
    )
    |> Repo.update_all(inc: [{:treasury, refund_price}, {buildable_to_demolish, -1}])

    # {:error, err} ->
    #   Logger.error(inspect(err))
    #   {:error, err}

    # _ ->
    #   nil
    # end
  end

  # WORLD

  def create_world(attrs \\ %{}) do
    %World{}
    |> World.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_world!(integer) :: World.t()
  @doc """
  Gets a single World.

  Raises `Ecto.NoResultsError` if the World does not exist.

  ## Examples

      iex> get_world!(123)
      %World{}

      iex> get_world!(456)
      ** (Ecto.NoResultsError)

  """
  def get_world!(id), do: Repo.get!(World, id)

  @spec get_world(integer) :: World.t() | nil
  @doc """
  Gets a single World.

  Raises `Ecto.NoResultsError` if the World does not exist.

  ## Examples

      iex> get_world(123)
      %World{}

      iex> get_world(456)
      ** (Ecto.NoResultsError)

  """
  def get_world(id), do: Repo.get(World, id)

  @doc """
  update a World in the DB
  expects (%World struct, map of attributes to adjust)
  returns {:ok, %World} or {:error, changeset}

  ## Examples

      iex> update_world(world, %{day: world.day + 1})
      {:ok, %World{}}

  """
  def update_world(%World{} = world, attrs \\ %{}) do
    world
    |> World.changeset(attrs)
    |> Repo.update()
  end
end
