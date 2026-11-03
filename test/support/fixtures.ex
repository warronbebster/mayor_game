defmodule MayorGame.Fixtures do
  @moduledoc """
  Test data: users, towns and randomly-populated towns for exercising the game loop.
  """
  alias MayorGame.{City, Repo}
  alias MayorGame.Auth.User
  alias MayorGame.City.{Buildable, Citizens, Town}

  def user_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    %User{email: "mayor#{n}@example.com", nickname: "mayor#{n}", password_hash: "not-a-real-hash"}
    |> struct(attrs)
    |> Repo.insert!()
  end

  @doc """
  A town created the same way players create one (`City.create_town/1`), then updated with `attrs`.
  Pass `user: %User{}` to choose the owner. Towns count as active (logged in today) by default.
  """
  def town_fixture(attrs \\ %{}) do
    {user, attrs} = Map.pop_lazy(attrs, :user, &user_fixture/0)
    n = System.unique_integer([:positive])

    {:ok, town} = City.create_town(%{title: "town#{n}", region: "ocean", climate: "temperate", user_id: user.id})

    town
    |> Town.changeset(Map.put_new(attrs, :last_login, Date.utc_today()))
    |> Repo.update!()
  end

  @doc """
  A town with random buildings, resources, tax rates and citizens, for game loop tests.
  Uses `:rand`, so seed it for reproducible towns.
  """
  def random_town_fixture(day) do
    buildables =
      Buildable.buildables_list()
      |> Enum.filter(fn _ -> :rand.uniform() < 0.35 end)
      |> Map.new(&{&1, :rand.uniform(8) - 1})

    resources =
      ~w(steel missiles shields sulfur uranium water salt fish oil wood stone lithium food cows rice meat grapes wheat bread)a
      |> Map.new(&{&1, :rand.uniform(300) - 1})

    citizens =
      Enum.map(1..:rand.uniform(400), fn _ ->
        %{
          "age" => :rand.uniform(12_000),
          "education" => :rand.uniform(6) - 1,
          "preferences" => :rand.uniform(11)
        }
      end)

    town_fixture(
      buildables
      |> Map.merge(resources)
      |> Map.merge(%{
        region: Enum.random(Town.regions()),
        climate: Enum.random(Town.climates()),
        treasury: :rand.uniform(1_000_000),
        tax_rates: Map.new(0..5, &{to_string(&1), Float.round(:rand.uniform() * 0.9, 2)}),
        citizens_compressed: Citizens.compress_citizen_blob(citizens, day),
        citizen_count: length(citizens),
        retaliate: :rand.uniform() < 0.5
      })
    )
  end
end
