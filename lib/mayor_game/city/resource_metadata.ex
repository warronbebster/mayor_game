# updating structs
defmodule MayorGame.City.ResourceMetadata do
  use Accessible
  alias MayorGame.City.{Town}

  # defaults to nil for keys without values
  defstruct [
    :title,
    :description,

    # UI view controls
    :image_sources,
    :text_color_class,
    :city_stock_display
  ]

  @typedoc """
      this makes a type for %ResourceMetadata{} that's callable with MayorGame.City.Resource.t()
  """
  @type t :: %__MODULE__{
          title: atom,
          description: String.t() | nil,
          image_sources: list(String.t() | nil),
          text_color_class: String.t() | nil,
          city_stock_display: (any -> String.t() | nil)
          # city_stock_display: (Town.t() -> String.t() | nil)
        }
end
