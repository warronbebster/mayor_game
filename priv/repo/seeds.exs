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

# alias MayorGame.Auth.User
# alias MayorGame.City.{Details, Info, Citizens}

alias MayorGame.{Auth, City}

# create details
{:ok, details} = City.create_details(%{houses: 3, roads: 6, schools: 9})

# create citizens
{:ok, citizen} = City.create_citizens(%{money: 50, name: "citizen kane"})

# make random city name so it doesn't run into dupe problem
randomString = :crypto.strong_rand_bytes(4) |> Base.encode64() |> binary_part(0, 4)
cityName = String.replace(randomString, "/", "a") <> "ville"

# create city
{:ok, city} =
  City.create_info(%{
    region: "space",
    title: cityName,
    citizens: [citizen],
    details: details
  })

{:ok, user} =
  Auth.create_user(%{
    nickname: "user" <> String.replace(randomString, "/", "a"),
    info: city
  })
