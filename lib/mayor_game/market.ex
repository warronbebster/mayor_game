defmodule MayorGame.Market do
  import Ecto.Query
  alias MayorGame.Repo
  alias MayorGame.City.{Market}

  def create_market(attrs \\ %{}) do
    %Market{}
    |> Market.changeset(attrs)
    |> Repo.insert()
  end

  def list_markets() do
    Repo.all(Market) |> Repo.preload([:town])
  end

  def get_markets_by_city(arg) do
    Market
    |> where([r], ^arg.id == r.city_id)
    |> Repo.all()
  end

  def get_markets_by_resource(resource) do
    resource = to_string(resource)

    Market
    |> where([r], ^resource == r.resource)
    |> Repo.all()
  end

  def get_market(id) do
    Repo.get!(Market, id)
  end

  @doc """
  Updates a market.

  ## Examples

      iex> update_market(market, %{field: new_value})
      {:ok, %market{}}

      iex> update_market(market, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_market(%Market{} = market, attrs) do
    market
    |> Market.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a market.

  ## Examples

      iex> delete_market(market)
      {:ok, %Market{}}

      iex> delete_market(market)
      {:error, %Ecto.Changeset{}}

  """
  def delete_market(%Market{} = market) do
    Repo.delete(market)
  end
end
