defmodule MayorGame.City.Details do
  use Ecto.Schema
  import Ecto.Changeset

  schema "details" do
    field :houses, :integer
    field :roads, :integer
    field :schools, :integer
    # ok so basically
    # this "belongs to is called "city" but it belongs to the "info" schema
    # so there has to be a "whatever_id" field in the migration
    # automatically adds "_id" when looking for a foreign key, unless you set it
    belongs_to :info, MayorGame.City.Info

    timestamps()
  end

  @doc false
  def changeset(details, attrs) do
    details
    |> cast(attrs, [:roads, :schools, :houses, :info_id])
    |> validate_required([:roads, :schools, :houses, :info_id])
  end
end
