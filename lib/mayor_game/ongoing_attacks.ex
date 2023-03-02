defmodule MayorGame.OngoingAttacks do
  alias MayorGame.City.OngoingAttacks
  import Ecto.Query
  alias MayorGame.Repo

  def get_attackers(arg) do
    OngoingAttacks
    |> where([r], ^arg.id == r.attacked_id)
    |> Repo.all()
  end

  def get_attackers2(town) do
    Repo.all(Ecto.assoc(town, :attacked))
  end

  # def datasource() do
  #   Dataloader.Ecto.new(Repo, query: &query/2)
  # end

  # def query(queryable, _) do
  #   queryable
  # end
end
