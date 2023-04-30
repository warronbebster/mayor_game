defmodule MayorGame.Sanctions do
  alias MayorGame.City.{OngoingSanctions, Town}
  import Ecto.Query
  alias MayorGame.Repo

  def get_sanctions(town) do
    OngoingSanctions
    |> where([r], ^town.id == r.sanctioned_id)
    |> Repo.all()
  end

  @doc """
  Creates a new ongoing sanction between too cities
  Takes the sanctioned_town as a struct, and the id of the sanctioning town
  """
  def get_sanctionss2(town) do
    Repo.all(Ecto.assoc(town, :sanctioned))
  end

  @doc """
  Creates a new ongoing sanction between too cities
  Takes the sanctioned_town as a struct, and the id of the sanctioning town
  """
  def initiate_sanctions(%{} = sanctioned_town, sanctioning_town_id) do
    # sanctioned_town_struct = sanctioned_town |> Repo.preload([:sanctions_sent, :sanctions_recieved, :sanctioning, :sanctioned])

    existing_sanctions =
      Repo.get_by(OngoingSanctions, sanctioned_id: sanctioned_town.id, sanctioning_id: sanctioning_town_id)

    if is_nil(existing_sanctions) do
      create_sanctions =
        Ecto.build_assoc(sanctioned_town, :sanctions_recieved, %{
          sanctioning_id: sanctioning_town_id
        })

      Repo.insert!(create_sanctions)
    else
      {:error, "existing sanction"}
    end
  end

  @doc """
  Creates a new ongoing sanction between too cities
  Takes the sanctioned_town as a struct, and the id of the sanctioning town
  """
  def remove_sanctions(%{} = sanctioned_town, sanctioning_town_id) do
    # sanctioned_town_struct = sanctioned_town |> Repo.preload([:sanctions_sent, :sanctions_recieved, :sanctioning, :sanctioned])

    existing_sanctions =
      Repo.get_by(OngoingSanctions, sanctioned_id: sanctioned_town.id, sanctioning_id: sanctioning_town_id)

    if !is_nil(existing_sanctions) do
      Repo.delete!(existing_sanctions)
    else
      {:error, "no existing sanctions"}
    end
  end

  # def datasource() do
  #   Dataloader.Ecto.new(Repo, query: &query/2)
  # end

  # def query(queryable, _) do
  #   queryable
  # end
end
