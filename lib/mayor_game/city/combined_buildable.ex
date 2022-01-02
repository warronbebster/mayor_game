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
    upgraded_metadata =
      if buildable.upgrades != [] do
        Enum.reduce(buildable.upgrades, metadata, fn buildable_upgrade, metadata_acc ->
          upgrade = Map.get(metadata_acc.upgrades, String.to_existing_atom(buildable_upgrade))
          # reduce over function map — each update each key by the function
          Enum.reduce(upgrade.function, metadata_acc, fn {key, function}, metadata_acc_2 ->
            Map.update!(metadata_acc_2, key, function)
          end)
        end)
      else
        metadata
      end

    %__MODULE__{
      buildable: buildable,
      metadata: upgraded_metadata
    }
  end
end
