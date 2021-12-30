# MayorGame

This is a zero-sum MMO. You get a township, and build a town to attract citizens — build schools, roads, transit systems, etc. Citizens will move to the best town for them — so you have to be competitive. However, the whole ecosystem shares one atmosphere — if everyone pollutes, citizens become sicker and sicker, eventually die, and the game ends for everyone — you'll be presiding over ghost towns.

## Running the game:

Make sure postgres is installed.

To start your Phoenix server:

`mix setup`

or

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `npm install` inside the `assets` directory

make sure Postgres is running, then start the Phoenix endpoint with `mix phx.server`

### Most of the important code is in `lib`

- `mayor_game` folder has the server stuff
  - `auth` has auth
  - `city` has modules for city stuff — buildables, citizens, details, info(cities)
    - `info.ex` has town info — it's the
    - `buildable.ex` has the multipliers for region-specific stuff
    - `city_calculator.ex` is how the city values are calculated each round
  - other files like city, repo are functions for DB calls / etc
- `mayor_game_web` has the live-view and web stuff

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? [Check Phoenixt deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix
