defmodule MayorGame.Bid do
  import Ecto.Query
  alias MayorGame.City.Bid
  alias MayorGame.Repo

  def create_bid(attrs \\ %{}) do
    %Bid{}
    |> Bid.changeset(attrs)
    |> Repo.insert()
  end

  def list_bids() do
    Repo.all(Bid) |> Repo.preload([:town])
  end

  def get_bids_by_city(city) do
    Bid
    |> where([r], ^city.id == r.city_id)
    |> Repo.all()
  end

  def get_bids_by_resource(resource) do
    resource = to_string(resource)

    Bid
    |> where([r], ^resource == r.resource)
    |> Repo.all()
  end

  def get_bid(id) do
    Repo.get!(Bid, id)
  end

  @doc """
  Updates a bid.

  ## Examples

      iex> update_bid(bid, %{field: new_value})
      {:ok, %bid{}}

      iex> update_bid(bid, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def update_bid(%Bid{} = bid, attrs) do
    bid
    |> Bid.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a bid.

  ## Examples

      iex> delete_bid(bid)
      {:ok, %Bid{}}

      iex> delete_bid(bid)
      {:error, %Ecto.Changeset{}}

  """
  def delete_bid(%Bid{} = bid) do
    Repo.delete(bid)
  end
end
