# updating structs
# %{losangeles | name: "Los Angeles"}

defmodule MayorGame.City.Buildable do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:upgrades]}

  embedded_schema do
    # has an id built-in
    field :enabled, :boolean
    field :reason, {:array, :string}
    field :upgrades, :map
  end

  # defstruct upgrades: %{}, id: 0, enabled: false

  @doc false
  def changeset(buildable, attrs \\ %{}) do
    buildable
    |> cast(attrs, [:enabled, :reason, :upgrades])
  end
end

#################

defmodule MayorGame.City.Buildable.Apartments do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:upgrades]}

  embedded_schema do
    # has an id built-in
    field :enabled, :boolean
    field :reason, {:array, :string}
    field :upgrades, :map
  end

  # defstruct upgrades: %{}, id: 0, enabled: false

  @doc false
  def changeset(buildable, attrs \\ %{}) do
    buildable
    |> cast(attrs, [:enabled, :reason, :upgrades])
  end
end

# ——————————————————————————————————————————————————————————————————

defmodule MayorGame.City.Upgrade do
  use Ecto.Schema

  embedded_schema do
    field :cost, :integer
    field :active, :boolean
    field :requirements, {:array, :string}
  end

  # defstruct cost: 10, active: false, requirements: []
end
