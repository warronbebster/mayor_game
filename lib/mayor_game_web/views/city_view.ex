defmodule MayorGameWeb.CityView do
  use MayorGameWeb, :view

  # attr :field, Phoenix.HTML.FormField
  # attr :rest, include: ~w(type)

  def input(assigns) do
    ~H"""
    <input id={@field.id} name={@field.name} value={@field.value} {@rest} />
    """
  end
end
