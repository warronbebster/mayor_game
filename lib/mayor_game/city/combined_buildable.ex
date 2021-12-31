# updating structs
defmodule MayorGame.City.CombinedBuildable do
  alias MayorGame.City.{Buildable, BuildableMetadata}
  # defaults to nil for keys without values
  defstruct buildable: %Buildable{}, metadata: %BuildableMetadata{}

  @typedoc """
      this makes a type for %CombinedBuildable{} that's callable with MayorGame.City.CombinedBuildable.t()
  """
  @type t :: %__MODULE__{
          buildable: Buildable.t(),
          metadata: BuildableMetadata.t()
        }

  @spec combine(Buildable.t(), BuildableMetadata.t()) :: t()
  def combine(buildable, metadata) do
    %__MODULE__{
      buildable: buildable,
      metadata: metadata
    }
  end
end
