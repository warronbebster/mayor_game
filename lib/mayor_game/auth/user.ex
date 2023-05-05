defmodule MayorGame.Auth.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema, extensions: [PowResetPassword, PowPersistentSession, PowEmailConfirmation]
  alias EctoCommons.EmailValidator

  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "auth_users" do
    # generic fields that POW generates for you? like email, id?
    pow_user_fields()

    field :nickname, :string
    # it's got once city
    # this means the town table gets a user_id column
    has_one :town, MayorGame.City.Town

    timestamps()
  end

  @doc false
  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
    |> cast(attrs, [:nickname])
    |> EmailValidator.validate_email(:email, checks: [:html_input, :burner, :check_mx_record])
    |> validate_length(:nickname, min: 1, max: 20)
    |> validate_required([:nickname])
    |> unique_constraint([:nickname])
    |> unique_constraint([:email])
  end
end
