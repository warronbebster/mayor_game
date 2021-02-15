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
alias MayorGame.City.{Details, Info, Citizens}

alias MayorGame.{Auth, City}

# create a user
{:ok, %User{id: madeUser_id}} =
  Auth.create_user(%{
    nickname: "user" <> String.replace(randomString, "/", "a"),
    email: randomString <> "@test.com",
    password: "password",
    confirm_password: "password"
  })

{:ok, %Info{id: madeInfo_id}} =
  City.create_city(%{
    region: "mountain",
    title: cityName,
    user_id: madeUser_id
  })

# create details
# first one doesn't work because it just makes a "details" entry in the DB. and we don't associate it later
# {:ok, %Details{}} = City.create_details(%{houses: 3, roads: 6, schools: 9, info_id: madeInfo_id})
# details = %Details{houses: 3, roads: 6, schools: 9}

# create citizens
{:ok, %Citizens{}} =
  City.create_citizens(%{money: 50, name: "citizen of " <> cityName, info_id: madeInfo_id})

# Ecto.build_assoc(user, :posts, %{header: "Clickbait header", body: "No real content"})
