defmodule MayorGame.Bid do
  # the bid context

  import Ecto.Query
  alias MayorGame.Market.Bid
  alias MayorGame.Repo
  alias MayorGame.City.Town

  def create_bid(attrs \\ %{}) do
    %Bid{}
    |> Bid.changeset(attrs)
    |> Repo.insert()
  end

  def list_bids() do
    Repo.all(Bid) |> Repo.preload([:town])
  end

  def list_valid_bids(date) do
    check_date = DateTime.add(date, -2_592_000, :second) |> DateTime.to_date()

    Repo.all(Bid)
    |> Repo.preload(
      town: from(t in Town, select: [:title, :last_login], where: fragment("?::date", t.last_login) >= ^check_date)
    )
    |> Enum.filter(fn b -> !is_nil(b.town) end)
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
