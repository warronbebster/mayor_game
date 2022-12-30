# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     MayorGame.Repo.insert!(%MayorGame.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# make random city name so it doesn't run into dupe problem
randomString = :crypto.strong_rand_bytes(4) |> Base.encode64() |> binary_part(0, 4)
cityName = String.replace(randomString, "/", "a") <> "ville"

alias MayorGame.Auth.User
alias MayorGame.City.{Town, Citizens}
alias MayorGame.{Auth, City}

# {:ok, %World{}} = City.create_world(%{day: 0, pollution: 0})

IO.puts('seeding!')

Auth.create_user(%{
  nickname: "bwebs",
  email: "hi@test.com",
  password: "password",
  confirm_password: "password"
})

# create a user
{:ok, %User{id: madeUser_id}} =
  Auth.create_user(%{
    nickname: "user" <> String.replace(randomString, "/", "a"),
    email: randomString <> "@test.com",
    password: "password",
    confirm_password: "password"
  })

# create a city
{:ok, %Town{id: madeTown_id}} =
  City.create_city(%{
    region: "mountain",
    climate: "arctic",
    resources: Map.new(MayorGame.City.Town.resources(), fn x -> {x, 0} end),
    title: cityName,
    tax_rate: %{0 => 0.5, 1 => 0.5, 2 => 0.5, 3 => 0.5, 4 => 0.5, 5 => 0.5, 6 => 0.5},
    user_id: madeUser_id
  })

# create citizens
{:ok, %Citizens{}} =
  City.create_citizens(%{
    money: 50,
    town_id: madeTown_id,
    age: 0,
    education: 0,
    has_car: false,
    last_moved: 0
  })
