defmodule MayorGame.Repo.Migrations.AddCombatBuildables do
  use Ecto.Migration

  def change do
    # obsoleted by 20210502000913_add_buildables
    ## create table(:air_bases) do
    ##   add :details_id, references(:details)
    ## 
    ##   timestamps()
    ## end
    ## 
    ## create index(:air_bases, [:details_id])
  end
end
