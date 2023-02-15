defmodule FormInput do
  # If you generated an app with mix phx.new --live,
  # the line below would be: use MyAppWeb, :live_component
  use Phoenix.LiveComponent

  # attr :field, Phoenix.HTML.FormField
  # attr :rest, include: ~w(type)

  def render(assigns) do
    ~H"""
    <input id={@field.id} name={@field.name} value={@field.value} {@rest} />
    """
  end
end
