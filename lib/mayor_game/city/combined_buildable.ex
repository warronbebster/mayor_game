# updating structs
defmodule MayorGame.City.CombinedBuildable do
  alias MayorGame.City.{Buildable, BuildableMetadata}
  # defaults to nil for keys without values
  @derive {Inspect, except: [:metadata]}
  defstruct buildable: %Buildable{}, metadata: %BuildableMetadata{}
  use Accessible

  @typedoc """
      this makes a type for %CombinedBuildable{} that's callable with MayorGame.City.CombinedBuildable.t()
  """
  @type t :: %__MODULE__{
          buildable: Buildable.t(),
          metadata: BuildableMetadata.t()
        }

  @spec combine(Buildable.t(), BuildableMetadata.t()) :: t()
  @doc """
      Takes a %Buildable{} and a %BuildableMetadata{} struct and returns %CombinedBuildable{} struct
  """
  def combine(buildable, metadata) do
    %__MODULE__{
      buildable: buildable,
      metadata: metadata
    }
  end

  @spec combine_and_apply_upgrades(Buildable.t(), BuildableMetadata.t()) :: t()
  @doc """
      Takes a %Buildable{} and a %BuildableMetadata{} struct and returns %CombinedBuildable{} struct
      But also applies the upgrades from %Buildable
  """
  def combine_and_apply_upgrades(buildable, metadata) do
    %__MODULE__{
      buildable: buildable,
      metadata: metadata
    }
  end
end
