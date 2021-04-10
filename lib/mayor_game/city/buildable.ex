# ok so these are both structs

defmodule MayorGame.City.Buildable do
  @derive {Jason.Encoder, only: [:id]}

  defstruct upgrades: %{}, id: 0
end

defmodule MayorGame.City.Upgrade do
  defstruct cost: 10, active: false, requirements: []
end

# updating structs
# %{losangeles | name: "Los Angeles"}
