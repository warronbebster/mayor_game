defmodule MayorGame.City.TownStats do
  alias __MODULE__
  alias MayorGame.City.{ResourceStats, BuildableStatistics}
  alias MayorGame.Rules
  use Accessible

  defstruct [
    :id,
    :title,
    :region,
    :climate,
    :season,
    :user,
    :patron,
    :contributor,
    :priorities,
    :tax_rates,
    :jobs_by_level,
    :vacancies_by_level,
    :total_citizens,
    :citizen_count_by_level,
    :employed_citizen_count_by_level,
    :resource_stats,
    :buildable_stats,
    :food_capacity,
    :food_consumed
  ]

  @type t ::
          %TownStats{
            # City
            id: integer | nil,
            title: String.t(),
            region: String.t(),
            climate: String.t(),

            # World
            season: atom,

            # user stats
            user: %MayorGame.Auth.User{},
            patron: integer,
            contributor: boolean,

            # controls in City
            priorities: %{String.t() => integer},
            tax_rates: %{integer => number},

            # objects in City
            jobs_by_level: %{integer => integer},
            vacancies_by_level: %{integer => integer},
            total_citizens: integer,
            citizen_count_by_level: %{integer => integer},
            employed_citizen_count_by_level: %{integer => integer},

            # changes
            resource_stats: %{atom => ResourceStats.t()},
            buildable_stats: %{atom => BuildableStatistics.t()},

            # food
            food_capacity: integer,
            food_consumed: integer
          }

  @spec fromTown(Town.t(), World.t()) :: TownStats.t()
  def fromTown(town, world) do
    %TownStats{
      id: town.id,
      title: town.title,
      region: town.region,
      climate: town.climate,
      season: Rules.season_from_day(world.day),
      user: town.user,
      patron: town.patron,
      contributor: town.contributor,
      priorities: town.priorities,
      tax_rates: town.tax_rates,
      jobs_by_level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
      vacancies_by_level: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
      total_citizens: length(town.citizens_blob),
      citizen_count_by_level: Enum.frequencies_by(town.citizens_blob, & &1["education"]),
      employed_citizen_count_by_level: %{},
      resource_stats:
        ResourceStats.resource_list()
        |> Enum.map(
          &{&1,
           %ResourceStats{
             title: to_string(&1),
             stock: town[&1],
             storage: 50,
             production: 0,
             consumption: 0
           }}
        )
        |> Enum.into(%{
          money: %ResourceStats{
            title: "money",
            stock: town.treasury,
            storage: nil,
            production: 0,
            consumption: 0
          },
          pollution: %ResourceStats{
            title: "pollution",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          energy: %ResourceStats{
            title: "energy",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          area: %ResourceStats{
            title: "area",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          housing: %ResourceStats{
            title: "housing",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          health: %ResourceStats{
            title: "health",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          fun: %ResourceStats{
            title: "fun",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          sprawl: %ResourceStats{
            title: "sprawl",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          culture: %ResourceStats{
            title: "culture",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          },
          crime: %ResourceStats{
            title: "crime",
            stock: 0,
            storage: nil,
            production: 0,
            consumption: 0
          }
        }),
      buildable_stats: %{},
      food_capacity: 0,
      food_consumed: 0
    }
  end

  @spec getResource(TownStats.t(), atom) :: ResourceStats.t()
  def getResource(town_stats, resource) do
    # fetch the resource stat from this struct. If it is not found, return an empty one
    Map.get(town_stats.resource_stats, resource, %MayorGame.City.ResourceStats{})
  end

  @spec getBuildable(TownStats.t(), atom) :: BuildableStatistics.t()
  def getBuildable(town_stats, buildable) do
    # fetch the buildable stat from this struct. If it is not found, return an empty one
    Map.get(town_stats.buildable_stats, buildable, %MayorGame.City.BuildableStatistics{})
  end
end
