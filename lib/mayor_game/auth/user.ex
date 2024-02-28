defmodule MayorGame.Auth.User do
  use Ecto.Schema

  use Pow.Ecto.Schema,
    user_id_field: :email,
    password_min_length: 6,
    password_max_length: 120

  use Pow.Extension.Ecto.Schema, extensions: [PowResetPassword, PowPersistentSession, PowEmailConfirmation]
  alias EctoCommons.EmailValidator

  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "auth_users" do
    field :nickname, :string
    field :is_alt, :boolean, default: false
    # it's got once city
    # this means the town table gets a user_id column
    has_one :town, MayorGame.City.Town

    # generic fields that POW generates for you? like email, id?
    pow_user_fields()

    timestamps()
  end

  @doc false
  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
    |> cast(attrs, [:nickname, :is_alt, :email])
    |> EmailValidator.validate_email(:email, checks: [:html_input, :burner, :check_mx_record])
    |> validate_length(:nickname, min: 1, max: 20)
    |> validate_length(:password, min: 6, max: 120)
    |> validate_required([:nickname, :email])
    |> unique_constraint(:nickname)
    |> unique_constraint(:email)
    |> IO.inspect()
  end
end
