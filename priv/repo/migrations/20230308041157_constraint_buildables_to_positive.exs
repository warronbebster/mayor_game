defmodule MayorGame.Repo.Migrations.ConstraintBuildablesToPositive do
  use Ecto.Migration
  import MayorGame.City.Buildable

  def change do
    for buildable <- buildables_list() do
      create constraint("cities", String.to_atom(to_string(buildable) <> "_must_be_positive"),
               check: "#{to_string(buildable)} >= 0"
             )
    end
  end
end
