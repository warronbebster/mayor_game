defmodule MayorGame.City.Town do
  @moduledoc """
      A %Town{} is the highest-level representation of a "town" in-game
      It contains:
      __meta__: Ecto.Schema.Metadata.t(),
      id: integer | nil,
      inserted_at: DateTime.t() | nil,
      updated_at: DateTime.t() | nil,
      title: String.t(),
      region: String.t(),
      climate: String.t(),
      tax_rates: map,
      user: %MayorGame.Auth.User{},
      citizens: list(Citizens.t()),
      pollution: integer,
      treasury: integer
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MayorGame.City.{Buildable, OngoingAttacks, OngoingSanctions, Market}
  alias MayorGame.Market.{Bid}
  use Accessible

  @timestamps_opts [type: :utc_datetime]

  logs_types = [
    :logs_edu,
    :logs_received,
    :logs_sent,
    :logs_births,
    :logs_deaths_attacks,
    :logs_deaths_housing,
    :logs_deaths_age,
    :logs_deaths_pollution,
    :logs_deaths_starvation,
    :logs_attacks,
    :logs_immigration,
    :logs_emigration_jobs,
    :logs_emigration_taxes,
    :logs_emigration_housing
  ]

  # don't print these on inspect
  @derive {Inspect, except: [:priorities, :citizens_compressed] ++ Buildable.buildables_list() ++ logs_types}

  @typedoc """
      Type for %Town{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t ::
          %__MODULE__{
            __meta__: Ecto.Schema.Metadata.t(),
            id: integer | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil,
            title: String.t(),
            region: String.t(),
            climate: String.t(),
            tax_rates: map,
            user: %MayorGame.Auth.User{},
            # citizens: list(Citizens.t()),
            pollution: integer,
            treasury: integer,
            citizen_count: integer,
            citizens_compressed: map,
            patron: integer,
            contributor: boolean,
            priorities: map,
            # combat
            retaliate: boolean,
            # logs ——————————————————————————————
            logs_emigration_housing: map,
            logs_emigration_taxes: map,
            logs_emigration_jobs: map,
            logs_immigration: map,
            logs_attacks: map,
            logs_edu: map,
            logs_sent: map,
            logs_received: map,
            logs_market_sales: map,
            logs_market_purchases: map,
            logs_deaths_pollution: integer,
            logs_deaths_starvation: integer,
            logs_deaths_age: integer,
            logs_deaths_housing: integer,
            logs_deaths_attacks: integer,
            logs_births: integer,

            # Resources————————————————————————————
            steel: integer,
            missiles: integer,
            shields: integer,
            sulfur: integer,
            gold: integer,
            # ^ unused
            uranium: integer,
            coal: integer,
            stone: integer,
            fish: integer,
            oil: integer,
            gas: integer,
            # ^ unused
            wood: integer,
            salt: integer,
            water: integer,
            lithium: integer,
            microchips: integer,
            sand: integer,
            glass: integer,
            # ^ unused
            cows: integer,
            rice: integer,
            wheat: integer,
            produce: integer,
            meat: integer,
            grapes: integer,
            bread: integer,
            wine: integer,
            beer: integer,
            food: integer,

            # Buildings ————————————————————————————
            huts: integer,
            single_family_homes: integer,
            multi_family_homes: integer,
            homeless_shelters: integer,
            apartments: integer,
            high_rises: integer,
            megablocks: integer,
            # transport
            roads: integer,
            highways: integer,
            airports: integer,
            bus_lines: integer,
            subway_lines: integer,
            bike_lanes: integer,
            bikeshare_stations: integer,
            gas_stations: integer,
            # energy
            coal_plants: integer,
            natural_gas_plants: integer,
            wind_turbines: integer,
            solar_plants: integer,
            nuclear_plants: integer,
            dams: integer,
            carbon_capture_plants: integer,
            # civic
            parks: integer,
            campgrounds: integer,
            nature_preserves: integer,
            libraries: integer,
            # education
            schools: integer,
            middle_schools: integer,
            high_schools: integer,
            universities: integer,
            research_labs: integer,
            # commercial
            retail_shops: integer,
            factories: integer,
            mines: integer,
            uranium_mines: integer,
            reservoirs: integer,
            oil_wells: integer,
            office_buildings: integer,
            distribution_centers: integer,
            theatres: integer,
            arenas: integer,
            zoos: integer,
            aquariums: integer,
            # medical
            hospitals: integer,
            doctor_offices: integer,
            # combat
            air_bases: integer,
            defense_bases: integer,
            missile_defense_arrays: integer,
            # storage
            wood_warehouses: integer,
            fish_tanks: integer,
            lithium_vats: integer,
            salt_sheds: integer,
            rock_yards: integer,
            water_tanks: integer,
            silos: integer,
            cow_pens: integer,
            refrigerated_warehouses: integer
          }

  schema "cities" do
    field(:title, :string)
    field(:region, :string)
    field(:climate, :string)
    field(:pollution, :integer)
    field(:treasury, :integer)
    field(:citizen_count, :integer)

    # RESOURCES
    field(:steel, :integer)
    field(:missiles, :integer)
    field(:shields, :integer)
    field(:sulfur, :integer)
    field(:gold, :integer)
    field(:uranium, :integer)
    field(:stone, :integer)
    field(:wood, :integer)
    field(:fish, :integer)
    field(:oil, :integer)
    field(:gas, :integer)
    field(:coal, :integer)
    field(:salt, :integer)
    field(:water, :integer)
    field(:lithium, :integer)
    field(:microchips, :integer)
    field(:sand, :integer)
    field(:glass, :integer)
    field(:cows, :integer)
    field(:rice, :integer)
    field(:wheat, :integer)
    field(:meat, :integer)
    field(:produce, :integer)
    field(:bread, :integer)
    field(:grapes, :integer)
    field(:food, :integer)
    field(:wine, :integer)
    field(:beer, :integer)

    field(:patron, :integer)
    field(:contributor, :boolean)
    field(:retaliate, :boolean)
    field :citizens_compressed, :map, null: false, default: %{}
    field :last_login, :date
    field :priorities, :map, null: false, default: Buildable.buildables_default_priorities()

    # this corresponds to an elixir list
    field(:tax_rates, :map)
    belongs_to(:user, MayorGame.Auth.User)

    # logs ——————————————————————————————
    field :logs_emigration_housing, :map, default: %{}
    field :logs_emigration_taxes, :map, default: %{}
    field :logs_emigration_jobs, :map, default: %{}
    field :logs_immigration, :map, default: %{}
    field :logs_attacks, :map, default: %{}
    field :logs_edu, :map, default: %{}
    field :logs_sent, :map, default: %{}
    field :logs_received, :map, default: %{}
    field :logs_market_sales, :map, default: %{}
    field :logs_market_purchases, :map, default: %{}
    field :logs_deaths_pollution, :integer, default: 0
    field :logs_deaths_starvation, :integer, default: 0
    field :logs_deaths_age, :integer, default: 0
    field :logs_deaths_housing, :integer, default: 0
    field :logs_deaths_attacks, :integer, default: 0
    field :logs_births, :integer, default: 0

    # outline relationship between city and citizens

    has_many :attacks_sent, OngoingAttacks, foreign_key: :attacking_id, on_delete: :delete_all
    has_many :attacks_recieved, OngoingAttacks, foreign_key: :attacked_id, on_delete: :delete_all
    has_many :attacking, through: [:attacks_sent, :attacked]
    has_many :attacked, through: [:attacks_recieved, :attacking]

    has_many :sanctions_sent, OngoingSanctions, foreign_key: :sanctioning_id, on_delete: :delete_all
    has_many :sanctions_recieved, OngoingSanctions, foreign_key: :sanctioned_id, on_delete: :delete_all
    has_many :sanctioning, through: [:sanctions_sent, :sanctioned]
    has_many :sanctioned, through: [:sanctions_recieved, :sanctioning]

    # markets
    has_many :markets, Market, on_delete: :delete_all
    has_many :bids, Bid, on_delete: :delete_all

    # buildable schema
    for buildable <- Buildable.buildables_list() do
      field(buildable, :integer)
    end

    timestamps()
  end

  def regions do
    [
      "ocean",
      "mountain",
      "desert",
      "forest",
      "lake"
    ]
  end

  def climates do
    [
      "arctic",
      "tundra",
      "temperate",
      "subtropical",
      "tropical"
    ]
  end

  def traits_minus_blob do
    [
      :id,
      :title,
      :pollution,
      :citizen_count,
      :treasury,
      :region,
      :climate,
      :user_id,
      :tax_rates,
      # resources
      :missiles,
      :shields,
      # resources
      :steel,
      :stone,
      :sulfur,
      :gold,
      :coal,
      :uranium,
      :water,
      :salt,
      :fish,
      :oil,
      :wood,
      :stone,
      :lithium,
      :sand,
      :glass,
      :food,
      :cows,
      :rice,
      :meat,
      :grapes,
      :produce,
      :wheat,
      :bread,
      :beer,
      :wine,
      :gas,

      # —————————————
      :patron,
      :contributor,
      :citizens_compressed,
      :last_login,

      # logs
      :logs_emigration_housing,
      :logs_emigration_taxes,
      :logs_emigration_jobs,
      :logs_immigration,
      :logs_attacks,
      :logs_edu,
      :logs_deaths_pollution,
      :logs_deaths_starvation,
      :logs_deaths_age,
      :logs_deaths_housing,
      :logs_deaths_attacks,
      :logs_market_purchases,
      :logs_market_sales,
      :logs_births,
      :logs_sent,
      :logs_received,
      :priorities,
      :retaliate
    ] ++ Buildable.buildables_list()
  end

  @doc false
  def changeset(%MayorGame.City.Town{} = town, attrs) do
    town
    # add a validation here to limit the types of regions
    |> cast(
      attrs,
      [
        :title,
        :pollution,
        :citizen_count,
        :treasury,
        :region,
        :climate,
        :user_id,
        :tax_rates,
        # resources
        :steel,
        :stone,
        :missiles,
        :shields,
        :sulfur,
        :gold,
        :uranium,
        :water,
        :salt,
        :fish,
        :oil,
        :gas,
        :wood,
        :stone,
        :lithium,
        :food,
        :cows,
        :rice,
        :meat,
        :grapes,
        :wheat,
        :bread,

        # —————————————
        :patron,
        :contributor,
        :citizens_compressed,
        :last_login,

        # logs
        :logs_emigration_housing,
        :logs_emigration_taxes,
        :logs_emigration_jobs,
        :logs_immigration,
        :logs_attacks,
        :logs_edu,
        :logs_deaths_pollution,
        :logs_deaths_starvation,
        :logs_deaths_age,
        :logs_deaths_housing,
        :logs_deaths_attacks,
        :logs_births,
        :logs_sent,
        :logs_received,
        :logs_market_purchases,
        :logs_received,
        :priorities,
        :retaliate
      ] ++ Buildable.buildables_list()
    )
    |> validate_required([:title, :region, :climate, :user_id])
    |> validate_length(:title, min: 1, max: 20)
    |> validate_inclusion(:region, regions())
    |> validate_inclusion(:climate, climates())
    |> unique_constraint(:title)
  end
end
