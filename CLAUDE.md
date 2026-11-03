# fragile.city (mayor_game)

A multiplayer city-builder: each player runs one town, and citizens move to whichever town suits them best.
All towns share one atmosphere, so pollution hurts everyone. Live at https://fragile.city.

Stack: Elixir 1.18 / OTP 27, Phoenix 1.7 (old-style `Phoenix.View` + templates, no `~p`),
LiveView 1.2, Ecto/Postgres, Pow for auth, Swoosh + Resend for email, Tailwind + esbuild. Hosted on Fly.io.

## Layout

- `lib/mayor_game/`: game logic and data
  - `city_calculator/city_calculator.ex`: **the game loop** (see below)
  - `city_calculator/city_helpers.ex`: per-city stats: production, consumption, jobs, food, births, deaths
  - `city_calculator/city_migrator.ex`: moving citizens between cities (pure `migrate/1` + `persist/3`)
  - `city_calculator/city_combat.ex`: missiles vs shields and buildings, ongoing attacks
  - `city_calculator/rules.ex`: formulas (building prices, taxes, lifespans, seasons, pollution ceiling)
  - `city/buildable.ex`: **every building's definition** (price, requirements, production, storage, regional multipliers)
  - `city/town.ex`: the `Town` schema (table `cities`), one integer column per building and per resource
  - `city/town_statistics.ex`, `city/resource_statistics.ex`: the structs the stats pipeline works on
  - `city/citizens.ex`: compressing and unfolding the citizen list
  - `market/`, `market.ex`, `bid.ex`: resource market; `sanctions.ex`: trade sanctions
  - `city.ex`: context with DB functions for towns and the world
- `lib/mayor_game_web/`: web
  - `live/city_live.ex`: a city's page, where nearly all player actions happen. `logs_live.ex`: its logs.
    `dashboard_live.ex`: the homepage (rendered by `PageController` via `live_render`). `market_live.ex`: the market.
  - `templates/`: LiveViews render these through Phoenix.View, e.g. `CityView.render("city.html", assigns)`
  - `views/paths.ex`: `city_path/1`; LiveView generates no route helpers for `live` routes, and titles need URL-encoding
- `notes.md`: the author's TODOs and ideas

## The game loop

`MayorGame.CityCalculator` is a single GenServer (started in `application.ex`, but not in tests). Each tick is one
game **day**, and runs every `:tick_interval_ms` (env `TICK_INTERVAL_MS`, 10s in prod, 5s in dev):

1. load every town active in the last 30 days (`CityHelpers.prepare_cities/3`) and unfold its citizens once
2. per city: `calculate_city_stats_with_drops/7` (a `%TownStats{}`), then `calculate_citizen_stats/8` (who stays,
   wants to move, is unemployed or unhoused, is born or dies)
3. write resources, treasury and pollution; settle market trades; resolve ongoing attacks
4. `CityMigrator.migrate/1` + `persist/3`: move citizens, add births, record deaths and emigration logs
5. increment `World.day` and pollution, then broadcast `"ping"` on `"cityPubSub"`. Every open LiveView then
   recomputes its city's stats, so per-tick cost scales with open tabs too.

Only one world exists (id 1, hardcoded in several places). Citizens are educated every 100 days.
CPU cost of a tick matters: it's most of the hosting bill (see "Deploying").

### Stats pipeline (`CityHelpers.calculate_city_stats/7`)

`TownStats.fromTown/2` seeds `resource_stats` (a `%ResourceStats{stock, production, consumption, storage, droplist}`
per resource) from the town's columns. Citizens eat food. Then buildings activate in the town's `priorities`
order (`fill_workers/3`): each needs its `requires` (area, energy, workers at an education level, resources), and
the loop restarts when a building produces something an earlier one was missing. Random `produces` entries are
functions (`fn rng, count -> amount end`) evaluated as "drops". Storage caps apply last.

### Citizens

Stored compressed in `cities.citizens_compressed` (JSON): `%{count => [citizen_type]}`, where a citizen type is
`%{"education" => 0..5, "preferences" => 1..11, "birthday" => day}`. Unfolded citizens are string-keyed maps that
also have `"age"` and `"town_id"`. See `Citizens.compress_citizen_blob/2` / `unfold_citizen_blob/3`.
`preferences` indexes `Citizens.preset_preferences/0`, which weights tax, pollution, sprawl, fun, health and culture.

### Migration rounds (`CityMigrator`)

Employed citizens looking to move, then unemployed, then unhoused citizens compete for job+housing slots at their
education level. Remaining unhoused citizens take any open housing, or die. Invariant (tested): every citizen
going in comes out in a city or in `unhoused_deaths`.

## Rules for changing code

- **Never trust LiveView event params.** Every `handle_event` must check on the server what the template only hides
  in the UI: `is_user_mayor` (owns this city), `is_user_verified`, `is_user_admin` (user id 1), market/bid ownership.
  Turn names into atoms only through a whitelist (`buildable/1`, `tradable_resource/1` in `CityLive`); a crafted
  atom used as a column name can change any column of a town. Unknown `priorities` keys crash the game loop,
  which calls `String.to_existing_atom` on every key.
- Handlers must always return `{:noreply, socket}`; an `if` without `else` returns nil and crashes the LiveView.
- Town columns have `>= 0` check constraints. Change counts with conditional atomic updates
  (`where: field(t, ^f) >= ^n` plus `inc:`), not by validating a stale struct. The LiveView's `@city` can be a tick old.
- Log maps (`logs_*`) come back from the DB with string keys (`CityHelpers.integerize_keys/1`).
- The game loop must not raise: one bad city or attack crashes the tick for everyone.
- Adding a buildable: define it in `Buildable` (`buildables_flat/0` and the ordering lists), and add a migration
  for its `cities` column (default 0) and `_must_be_positive` constraint. The schema field comes from
  `buildables_list/0`.

## Development

```bash
mix setup            # deps, create/migrate/seed the DB (local Postgres, postgres/postgres; see config/dev.exs)
iex -S mix phx.server  # http://localhost:5000
mix test             # needs Postgres; the game loop doesn't run in tests, tests call run_tick/1 directly
mix format           # .formatter.exs keeps <%= %> in templates (no {} migration)
```

Local overrides (e.g. another database) go in `config/dev.secret.exs` (gitignored; see the `.example`).
**The repo is public: never commit credentials.**

Tests: `test/support/fixtures.ex` (`town_fixture/1`, `random_town_fixture/1` for whole random cities,
`user_fixture/1`), and `ConnCase.log_in/2`, which signs in through the real session endpoint, for LiveView tests.

### In a Claude Code cloud sandbox

Elixir may not be installed, but Docker is: start `sudo dockerd &`, run Postgres with
`docker run -d --network host -e POSTGRES_PASSWORD=postgres postgres:15-alpine`, and run mix in
`hexpm/elixir:1.18.4-erlang-27.3.4.16-debian-bookworm-20260824-slim` with `--network host`, the repo mounted at
`/app`, and the proxy env plus CA (`HTTPS_PROXY`, `HEX_CACERTS_PATH`, `SSL_CERT_FILE` → `/root/.ccr/ca-bundle.crt`).
Needs `repo.hex.pm` and `builds.hex.pm` allowed in the environment's network settings. The sandbox has no IPv6,
so the production image only boots there with its IPv6 settings (`ERL_AFLAGS`, `ECTO_IPV6`, the `::` bind) turned off.

## Deploying

Pushing to `main` deploys to Fly (`.github/workflows/fly.yml` → `flyctl deploy --remote-only`) with the `Dockerfile`
(Debian bookworm), running `/app/bin/migrate` first. `fly.toml`: app `mayorgame`, one `shared-cpu-2x` machine.
If ticks get slow (the log prints `Calculator Tick | Time: N ms`), raise `TICK_INTERVAL_MS` before moving to a
performance VM. Fly secrets: `DATABASE_URL`, `SECRET_KEY_BASE`, `RESEND_API_KEY` (emails are only logged without it;
the sender `app@fragile.city` must be verified in Resend). Fly uses IPv6 internally, hence `ECTO_IPV6` and
`ERL_AFLAGS` in the Dockerfile.
