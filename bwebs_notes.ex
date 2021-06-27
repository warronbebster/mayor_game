# society simulator 2021

# todo:

# maybe add global limits for amount of cities… artificial scarcity?
# one per email, in that case? no redos, baybeee
# is this just as simple as changing has_many to has_one in user.ex?
# 10000 possible cities, 2500 in each environment

# sort cities on homepage by citizen count

# error handling/routing for wrong urls

# figure out how to release prod version

# add upgrading system for buildables (like a park can have a soccer field, etc)
# this would mean changing the details schema to a list of buildings instead of int
# or maybe you can just buy like, categorical upgrades (like, "solar roofs")
# maybe this should me a map instead of a list
# maybe you can built apartment buildings of any story, but it's exponentially more expensive?

[
  %{
  upgrades: %{
    upgrade_name: %{cost: int, active: false, requirements: [:upgrade_name]},
    upgrade_name: %{cost: int, active: false, requirements: [:upgrade_name]}
  },
  id: #
  }
]

# clean up preload situation across the board

# clean up calculate_ functions to only enum through buildables once?
# i think i can do this by just having different preliminary functions before enumerating through the main buildable list
# and maybe I have to store whether they're enabled or not in that enum

# figure out why moving logs make tax logs not appear?
# figure out why taxer stops sometimes

# make a "world" variable for CO2/pollution? that affects every city?
# write to world.pollution every day

# function to loan/give other cities money?

# eventually could write calculate functions with Stream instead of Enum to speed up

# implement regional differences (check region in generation functions) (done for energy, should do for fun)

# add hospitals, doctor offices and other health impacts stats (factory work? parks?)
# make pollution kill people (does pollution just impact health directly?)
# add grocery stores? farmers markets? farms?
# add "fun" and "health" calculations to check for
# add water power (more effective in mountains, less in desert)

# add general "policy" options
# (speed limits — increase sprawl, increase health)
# (bike lanes?)

# probably should move treasury out of details and reserve details just for buildables

# — adjust auth so you can only control your own cities (done on front-end)
#   — might need to do this on the backend with a constraint or something in case haxkorz
#   — (although maybe you just couldn't send to the submit action from console?)

# — adjust signin/session time limit (maybe done with persistent session plugin?)




# ——————————————————————————————————————————————————————————————
# phx.gen.context in terminal to generate different contexts;

# auth context with "user" struct

# "city" context, that belongs to user?
#  - type, atom (forest, ocean, mountain, etc) only one type
#  - title, string. only one title
#  - owner, User struct. belongs to. only one owner
#  - log, of changes, of list?
#  - citizens, of type list of structs Citizen?[]

# "citizen" context, that belongs to city?

# basically, anything that can "have" something else belong to it needs an _id field.
# This is guessed automatically as the foreign key when outlining that stuff

# :rand.uniform() random float between 0 and 1

mix phx.gen.context City Info cities \
  title:string \
  user_id:references:auth_users \
  region:string

mix phx.gen.context City Citizens citizens \
  name:string \
  money:integer \
  city:references:cities \

mix phx.gen.context City Details details \
  roads:integer \
  schools:integer \
  single_family_homes:integer \
  city:references:cities

# so after running all these, they get migration files in /priv/repo/migrations


# to adjust database:
# first, make an ecto migration
mix ecto.gen.migration _name

# then in /priv/repo/migrations it'll make a file you can edit
mix ecto.migrate
# or
mix ecto.rollback to undo

mix ecto.reset to reset the whole db

# to run the seeds:
mix run priv/repo/seeds.exs


# this format is called "Pipe merging:" https://joyofelixir.com/10-maps
# combines two maps to update existing map
iex> izzy = %{"name" => "Izzy", "age" => "30ish", "gender" => "Female"}
%{"age" => "30ish", "gender" => "Female", "name" => "Izzy"}
iex> %{izzy | "age" => "40ish", "name" => "Isadora"}
%{"age" => "40ish", "gender" => "Female", "name" => "Isadora"}


# ok for pubsub… theoretically, they all need to be subscribed to the same pubsub system to get updates, right?



fake user:
hi@test.com
barron
pw: barronbarron


————————————————————————————————————————————————————————
OTP stuff


{:ok, mover} = MayorGame.Mover.start_link(10)

ok so in the rumble example, the *client* starts a task. it does it async
maybe that makes sense in this case? but idk


# ok this worked when trying to preload stuff
Repo.all(MayorGame.City.Citizens) |> Repo.preload([:info])


# get stuff from a struct with the key atom:
Map.get(city.detail, building_type)
