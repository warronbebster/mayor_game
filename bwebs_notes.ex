# society simulator 2021

# TODO:


# implement regional differences (check region in generation functions) (done for energy, should do for health & fun)
# figure out why server sometimes doesn't restart

# FIRST RELEASE DONE

# https://community.fly.io/t/need-help-with-postgresql/3971
# https://community.fly.io/t/increase-diskspace-for-postgresql/8964
# https://fly.io/blog/volumes-expand-restore/
# fly postgres connect -a mayorgame-db connects to prod DB
# fly volumes list --app mayorgame-db gets volumes from the db project thingy


# do some optimization to update_city_by_title, see if calculator and migrator can just send changes instead of having the city_live server recalculate it every time
# flow some more calculations for optimization
# add crime (random deaths)
  # also based on jobless people
# add homeless people
# add job specialization (police, etc)
# maybe make pubsub for each city when it's opened to subscribe to updates from other cities attacking u?
# consider separating money/resource generation ticks from citizen movement ticks?
# ^ Do this with an entirely seperate process
# potentially use list.keysort instead of sort_by for perf reasons
# could just save a set of pre-defined preference maps and each "citizen" could reference them
# that would mean just having a "class" perhaps for citizenSegments
# I should do that. The only thing stopping it is discrete age. Maybe I just capture the "origin date" for an entire class
# spread workers over buildables instead of only filling one type first
# batch citizen counts. make age way broader
# don't need to actually encode city buildables as full maps, i think operating count is enough. maybe the only point is for job gen?
# ok day ticks aren't that much longer than move ticks now that some cities are filtered out. Either need to make resource ticks much faster or combine again
# on purchases, actually check requirements and enforce them before sending building back
# add "building" state to buildings you just built

logs:
move-outs by reason
- level
- city moved to

move-ins
- level
- city from

educations per level

deaths
-pollution
-age
-housing

births

attacks
- shields
- which city
- which building







### nice to have —————————————————————————————————————
# fix taxes so you can't get money from non active-workers
# ^ did I do this? I think so
# just pass the whole city through

#
# add script to randomly add citizens sometimes
# clean db writes out of buildable resets
# consolidate job calculations

# add grocery stores? farmers markets? farms?

# add general "policy" options that aren't buildings
# (speed limits — increase sprawl, increase health)
# (bike lanes?)

# maybe add global limits for amount of cities… artificial scarcity?
# 1000 possible cities?

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
