# fragile.city

# https://community.fly.io/t/need-help-with-postgresql/3971
# https://community.fly.io/t/increase-diskspace-for-postgresql/8964
# https://fly.io/blog/volumes-expand-restore/
# fly postgres connect -a mayorgame-db connects to prod DB
# fly volumes list --app mayorgame-db gets volumes from the db project thingy



#TODO
# do some optimization to update_city_by_title, see if calculator and migrator can just send changes instead of having the city_live server recalculate it every time

# factions — allow people to select a specific color / faction to display
# maybe if you have a certain building, you can create a faction
# flow some more calculations for optimization

# prevent exchange?
# add ability to turn a number of buildings off
# maybe you can choose to open up to migration/trade, you can do everything in your own city (north korea style) but won't get any talented people moving

# Just like the real world, make all-out war a last resort. Introduce trade treaties and sanctions as a way to coerce different cities, without directly attacking them.
# Introduce faction rules so that players can coordinate sharing resources or coordinate combat as a group.
# build tabs in the city interface
# add date logs for attacks

# add crime (random deaths)
  # also based on jobless people
  # police stations
  # add job specialization (police, scientist, etc)
# maybe make pubsub for each city when it's opened to subscribe to updates from other cities attacking u?
# add food
# add building requirements

# potentially use list.keysort instead of sort_by for perf reasons

# don't need to actually encode city buildables as full maps, i think operating count is enough. maybe the only point is for job gen?
# ok day ticks aren't that much longer than move ticks now that some cities are filtered out. Either need to make resource ticks much faster or combine again
# on purchases, actually check requirements and enforce them before sending building back






### nice to have —————————————————————————————————————

# just pass the whole city through

# clean db writes out of buildable resets
# consolidate job calculations

# add general "policy" options that aren't buildings
# (speed limits — increase sprawl, increase health)
# (bike lanes?)

# error handling/routing for wrong urls — route back to home

# clean up preload situation across the board

# clean up calculate_ functions to only enum through buildables once?
# i think i can do this by just having different preliminary functions before enumerating through the main buildable list
# and maybe I have to store whether they're enabled or not in that enum

# function to loan/give other cities money?

# eventually could write calculate functions with Stream instead of Enum to speed up

# trading — send money, etc to other cities and put it in a log
# fighter jets
# if there are no fighter jets, destroying air-bases takes missiles out as well
# cap on shields from defense bases



# TYPES:
# https://elixirforum.com/t/struct-vs-type-t/32124

# TIMESTAMPS:
# http://www.creativedeletion.com/2019/06/17/utc-timestamps-in-ecto.html

# PASSING FUNCTIONS:
# https://stackoverflow.com/questions/22562192/how-do-you-pass-a-function-as-a-parameter-in-elixir
# https://www.culttt.com/2016/05/09/functions-first-class-citizens-elixir

# The buildable comes from the server, I think, and then the metadata gets calculated on the fly?


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

mix phx.gen.context City Town cities \
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

# see routes
mix phx.routes

# start the server project
mix phx.server

# run iex for the project
iex -S mix phx.server

# to adjust database:
# first, make an ecto migration
mix ecto.gen.migration _name

# then in /priv/repo/migrations it'll make a file you can edit
mix ecto.migrate
# or
mix ecto.rollback # to undo
# or
mix ecto.reset # to reset the whole db

# to run the seeds:
mix run priv/repo/seeds.exs


# fake user:
# hi@test.com
# barron
# pw: barronbarron


————————————————————————————————————————————————————————
OTP stuff

{:ok, mover} = MayorGame.Mover.start_link(10)

ok so in the rumble example, the *client* starts a task. it does it async
maybe that makes sense in this case? but idk

# ok this worked when trying to preload stuff
Repo.all(MayorGame.City.Citizens) |> Repo.preload([:town])

# get stuff from a struct with the key atom:
Map.get(city.details, building_type)


root.html.eex goes on every page
live.html.eex might wrap every live thingy?
