defmodule MayorGame.City.TownMigrationStatistics do
  alias __MODULE__
  alias MayorGame.City.{Citizens}
  use Accessible

  defstruct [
    :id,
    :title,
    aggregate_births: 0,
    aggregate_deaths_by_age: 0,
    aggregate_deaths_by_pollution: 0,
    educated_citizens: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
    housing_left: 0,
    staying_citizens: [],
    migrating_citizens_due_to_tax: [],
    migrating_citizens: [],
    unemployed_citizens: [],
    unhoused_citizens: [],
    polluted_citizens: []
  ]

  @type t ::
          %TownMigrationStatistics{
            # City
            id: integer | nil,
            title: String.t(),
            aggregate_births: integer,
            aggregate_deaths_by_age: integer,
            aggregate_deaths_by_pollution: integer,
            educated_citizens: %{integer => integer},
            housing_left: integer,
            staying_citizens: list(Citizens.t()),
            migrating_citizens_due_to_tax: list(Citizens.t()),
            migrating_citizens: list(Citizens.t()),
            unemployed_citizens: list(Citizens.t()),
            unhoused_citizens: list(Citizens.t()),
            polluted_citizens: list(Citizens.t())
          }

  @spec fromTown(Town.t()) :: TownMigrationStatistics.t()
  def fromTown(town) do
    %TownMigrationStatistics{
      id: town.id,
      title: town.title,
      aggregate_births: 0,
      aggregate_deaths_by_age: 0,
      aggregate_deaths_by_pollution: 0,
      educated_citizens: %{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0},
      housing_left: 0,
      staying_citizens: [],
      migrating_citizens_due_to_tax: [],
      migrating_citizens: [],
      unemployed_citizens: [],
      unhoused_citizens: [],
      polluted_citizens: []
    }
  end
end
