defmodule MayorGame.Repo.Migrations.AddMinesAndOtherBuildables do
  use Ecto.Migration

  def change do
    # obsoleted by 20210502000913_add_buildables
    ## create table(:mines) do
    ##   add :details_id, references(:details)
    ##   timestamps()
    ## end
    ## 
    ## create table(:defense_bases) do
    ##   add :details_id, references(:details)
    ##   timestamps()
    ## end
    ## 
    ## create index(:mines, [:details_id])
    ## create index(:defense_bases, [:details_id])
  end
end
