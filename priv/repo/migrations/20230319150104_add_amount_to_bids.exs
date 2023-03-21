defmodule MayorGame.Repo.Migrations.AddAmountToBids do
  use Ecto.Migration

  def change do
    alter table(:bids) do
      add :amount, :integer, default: 1
    end

    create constraint("bids", :amount_must_be_positive, check: "amount > 0")
  end
end
