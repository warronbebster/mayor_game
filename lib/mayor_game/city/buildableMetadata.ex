# updating structs
defmodule MayorGame.City.BuildableMetadata do
  # defaults to nil for keys without values
  defstruct [
    :price,
    :fits,
    :daily_cost,
    :area_required,
    :energy_required,
    :upgrades,
    :purchasable_reason,
    :jobs,
    :job_level,
    :education_level,
    :capacity,
    :sprawl,
    :area,
    :energy,
    :pollution,
    :region_energy_multipliers,
    :season_energy_multipliers,
    purchasable: true
  ]

  @typedoc """
      this makes a type for %BuildableMetadata{} that's callable with MayorGame.City.Buildable.t()
  """
  @type t :: %__MODULE__{
          price: integer | nil,
          fits: integer | nil,
          daily_cost: integer | nil,
          area_required: nil,
          energy_required: nil,
          purchasable: true,
          upgrades: map() | nil,
          purchasable_reason: nil,
          job_level: 1..5,
          sprawl: 10,
          area: 10
        }

  @doc """
  Map of buildables with format %{
    category: %{
      buildable_name: %{
        buildable_detail: int
      }
    }
  }
  """
end
