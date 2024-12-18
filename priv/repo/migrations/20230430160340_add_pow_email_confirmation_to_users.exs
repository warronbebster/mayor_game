defmodule MayorGame.Repo.Migrations.AddPowEmailConfirmationToUsers do
  use Ecto.Migration
  import Ecto.Query

  def change do
    alter table(:auth_users) do
      add :email_confirmation_token, :string
      add :email_confirmed_at, :utc_datetime
      add :unconfirmed_email, :string
    end

    # flush()

    # from(u in MayorGame.Auth.User,
    #   where: u.id < 100,
    #   update: [set: [unconfirmed_email: u.email]]
    # )
    # |> MayorGame.Repo.update_all([])
    # ok so basically I also have to give each user a token. wat is the token

    create unique_index(:auth_users, [:email_confirmation_token])
  end
end
