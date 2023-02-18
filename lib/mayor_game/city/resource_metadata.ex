# updating structs
defmodule MayorGame.City.ResourceMetadata do
  use Accessible

  # defaults to nil for keys without values
  defstruct [
    :category,
    :title,
    :description,

    # UI view controls
    :image_source,
    :text_color_class
  ]

  @typedoc """
      this makes a type for %ResourceMetadata{} that's callable with MayorGame.City.ResourceMetadata.t()
  """
  @type t :: %__MODULE__{
          category: atom,
          title: atom,
          description: String.t() | nil,
          image_source: String.t() | nil,
          text_color_class: String.t() | nil
        }
end
