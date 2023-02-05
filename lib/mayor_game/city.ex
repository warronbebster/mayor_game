defmodule MayorGame.City do
  @moduledoc """
  The City context.
  """

  # THIS IS WHAT TALKS TO ECTO
  require Logger
  import Ecto.Query, warn: false
  alias MayorGame.Repo
  alias MayorGame.City.{Town, Citizens, World, Buildable}

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
  def list_cities_preload do
    Repo.all(Town) |> Repo.preload([:citizens, :user])
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
    resourceMap = %{resources: Map.new(MayorGame.City.Town.resources(), fn x -> {x, 0} end)}

    buildables_zeroed =
      Enum.map(Buildable.buildables_ordered_flat(), fn k ->
        {k, 0}
      end)
      |> Enum.into(%{})

    intro_attrs =
      %{
        treasury: 5000,
        pollution: 0,
        citizen_count: 0,
        missiles: 0,
        shields: 0,
        gold: 0,
        sulfur: 0,
        uranium: 0
      }
      |> Map.merge(buildables_zeroed)

    # make sure keys are atoms, helps with input from phoenix forms
    attrsWithAtomKeys =
      Map.new(attrs, fn {k, v} ->
        {if(!is_atom(k), do: String.to_existing_atom(k), else: k), v}
      end)
      |> Map.merge(intro_attrs)

    %Town{}
    |> Town.changeset(Map.merge(attrsWithAtomKeys, resourceMap))
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

  # might not need to type guard here because DB does it; but
  @doc """
  updates log for a city. Expects the town(city) struct & a single string.

  ## Examples
      iex> update_log(town, "string to add to log")
      {:ok, %Town{}}

      iex> update_town(town, bad_value)
      {:error, %Ecto.Changeset{}}
  """
  def update_log(%Town{} = town, log_item) do
    # add new item to head of list
    updated_log = [log_item | town.logs]

    # if list is longer than 50, remove last item
    limited_log =
      if length(updated_log) > 50 do
        updated_log |> Enum.reverse() |> tl() |> Enum.reverse()
      else
        updated_log
      end

    town
    |> Town.changeset(%{logs: limited_log})
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

  # ###############################################
  # CITIZENS CITIZENS CITIZENS CITIZENS CITIZENS CITIZENS
  # ###############################################

  @doc """
  Returns the list of citizens.

  ## Examples

      iex> list_citizens()
      [%Citizens{}, ...]

  """
  def list_citizens do
    Repo.all(Citizens)
  end

  def list_citizens_preload do
    Repo.all(Citizens) |> Repo.preload([:town])
  end

  @doc """
  Gets a single citizens.

  Raises `Ecto.NoResultsError` if the Citizens does not exist.

  ## Examples

      iex> get_citizens!(123)
      %Citizens{}

      iex> get_citizens!(456)
      ** (Ecto.NoResultsError)

  """
  def get_citizens!(id), do: Repo.get!(Citizens, id)

  @doc """
  Creates a citizens.

  ## Examples

      iex> create_citizens(%{field: value})
      {:ok, %Citizens{}}

      iex> create_citizens(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_citizens(attrs \\ %{}) do
    # this makes a map with random values that add up to 1
    random_preferences =
      Enum.reduce(Citizens.decision_factors(), %{preference_map: %{}, room_taken: 0}, fn x, acc ->
        value =
          if x == List.last(Citizens.decision_factors()),
            do: (1 - acc.room_taken) |> Float.round(2),
            else: (:rand.uniform() * (1 - acc.room_taken)) |> Float.round(2)

        %{
          preference_map: Map.put(acc.preference_map, to_string(x), value),
          room_taken: acc.room_taken + value
        }
      end)

    # Map.new(Citizens.decision_factors(), fn x ->
    #   {to_string(x), :rand.uniform() |> Float.round(2)}
    # end)

    # add new attribute if not set
    attrs_plus_preferences =
      attrs
      |> Map.put_new(:name, Faker.Person.name())
      |> Map.put(:preferences, random_preferences.preference_map)

    %Citizens{}
    |> Citizens.changeset(attrs_plus_preferences)
    |> Repo.insert()
  end

  @doc """
  Creates a citizens changeset

  ## Examples

      iex> create_citizens(%{field: value})
      {:ok, %Citizens{}}

      iex> create_citizens(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_citizens_changeset(attrs \\ %{}) do
    # this makes a map with random values that add up to 1
    random_preferences =
      Enum.reduce(Citizens.decision_factors(), %{preference_map: %{}, room_taken: 0}, fn x, acc ->
        value =
          if x == List.last(Citizens.decision_factors()),
            do: (1 - acc.room_taken) |> Float.round(2),
            else: (:rand.uniform() * (1 - acc.room_taken)) |> Float.round(2)

        %{
          preference_map: Map.put(acc.preference_map, to_string(x), value),
          room_taken: acc.room_taken + value
        }
      end)

    # Map.new(Citizens.decision_factors(), fn x ->
    #   {to_string(x), :rand.uniform() |> Float.round(2)}
    # end)

    # add new attribute if not set
    attrs_plus_preferences =
      attrs
      |> Map.put_new(:name, Faker.Person.name())
      |> Map.put(:preferences, random_preferences.preference_map)

    %Citizens{}
    |> Citizens.changeset(attrs_plus_preferences)
  end

  @doc """
  Updates a citizens.

  ## Examples

      iex> update_citizens(citizens, %{field: new_value})
      {:ok, %Citizens{}}

      iex> update_citizens(citizens, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_citizens(%Citizens{} = citizens, attrs) do
    citizens
    |> Citizens.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a citizens.

  ## Examples

      iex> delete_citizens(citizens)
      {:ok, %Citizens{}}

      iex> delete_citizens(citizens)
      {:error, %Ecto.Changeset{}}

  """
  def delete_citizens(%Citizens{} = citizens) do
    Repo.delete(citizens)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking citizens changes.

  ## Examples

      iex> change_citizens(citizens)
      %Ecto.Changeset{data: %Citizens{}}

  """
  def change_citizens(%Citizens{} = citizens, attrs \\ %{}) do
    Citizens.changeset(citizens, attrs)
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
  def purchase_buildable(%Town{} = city, field_to_purchase, purchase_price) do
    city_attrs = %{treasury: city.treasury - purchase_price}

    purchase_city =
      city
      |> Town.changeset(city_attrs)
      |> Ecto.Changeset.validate_number(:treasury, greater_than: 0)
      |> Repo.update()

    case purchase_city do
      {:ok, _result} ->
        from(t in Town,
          where: [id: ^city.id]
        )
        |> Repo.update_all(inc: [{field_to_purchase, 1}])

      {:error, err} ->
        Logger.error(inspect(err))

      _ ->
        nil
    end
  end

  @doc """
  remove 1 of a given building
  expects (details, :atom of building, building id)

  ## Examples

      iex> demolish_buildable(details, :schools, buildable_id int)
      {:ok, %Details{}}

  """
  def demolish_buildable(%Town{} = city, buildable_to_demolish) do
    refund_price = Buildable.buildables_flat()[buildable_to_demolish].price

    Town
    |> where(id: ^city.id)
    |> update(inc: [treasury: ^refund_price])
    |> Repo.update_all(inc: [{buildable_to_demolish, -1}])
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
