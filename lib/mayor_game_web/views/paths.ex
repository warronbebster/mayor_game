defmodule MayorGameWeb.Paths do
  @moduledoc """
  Paths for LiveView routes (LiveView doesn't generate route helpers for `live` routes).
  Imported into every view.
  """

  @doc "Path to a city's page; titles can contain spaces and other characters that need encoding."
  def city_path(title), do: "/city/" <> URI.encode(title, &URI.char_unreserved?/1)

  def city_logs_path(title), do: city_path(title) <> "/logs"
end
