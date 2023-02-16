# [fragile.city](https://www.fragile.city/)

This is a zero-sum MMO. You get a township, and build a town to attract citizens — build schools, roads, transit systems, etc. Citizens will move to the best town for them — so you have to be competitive. However, the whole ecosystem shares one atmosphere — if everyone pollutes while building their towns, citizens become sicker and sicker, eventually die, and the game ends for everyone — you'll be presiding over a ghost town.

docs:
[phoenix liveview](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
[mnesia](https://elixirschool.com/en/lessons/storage/mnesia)

## Running the game:

Make sure postgres is installed.

To start your Phoenix server:

`mix setup`

or

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `npm install` inside the `assets` directory
  - this might not be a thing anymore

make sure Postgres is running, then start the Phoenix endpoint with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Most of the important code is in `lib`

- `mayor_game` folder has the server stuff
  - `auth` has auth
  - `city` has modules for city stuff — buildables, citizens, details, town(cities)
    - `town.ex` has town town — it's the
    - `buildable.ex` has the multipliers for region-specific stuff
    - `city_calculator.ex` is how the city values are calculated each round
  - other files like city, repo are functions for DB calls / etc
- `mayor_game_web` has the live-view and web stuff

to add new buildables:

1. add in buildable.ex
2. `mix ecto.reset`
3. `mix run priv/repo/seeds.exs`

Ready to run in production? [Check Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Deployment

The game can be deployed to fly.io via the auto-generated `Dockerfile`:

```
$ fly launch   # Opt-in to creating a Postgres database
$ fly deploy
$ fly open
```

To view production logs

```
$ fly logs
```

See: https://mayor.fly.dev

to reset the prod DB — iex in and run `Ecto.Migrator.run(MyApp.Repo, :down, all: true)`, then redeploy

To IEX in to prod:

```
fly ssh console
app/bin/mayor_game remote
world = MayorGame.City.get_world(1)
MayorGame.City.update_world(world, %{pollution: 1000000})
city = MayorGame.City.get_town_by_title!("wat")
MayorGame.City.update_town(city, %{patron: 1})


```

to connect to DB:
`fly postgres connect -a mayorgame-db`
`select name, setting from pg_settings where name like '%wal_size%' or name like '%checkpoint%' order by name;`
`\c mayorgame;`

edit db config:
`fly ssh console -a mayorgame-db`
cd data
cd postgres

restart DBs:
`fly pg restart -a mayorgame-db`

see db machine details
`fly machine status 73287903f11685 -a mayorgame-db`

scaling fly postgres
https://fly.io/docs/postgres/managing/scaling/

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix
