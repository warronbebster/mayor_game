defmodule MayorGameWeb.RegistrationController do
  use MayorGameWeb, :controller

  alias Ecto.Changeset
  alias MayorGame.Repo

  def resend_confirmation_email(conn, _params) do
    user = Pow.Plug.current_user(conn)

    case PowEmailConfirmation.Plug.pending_email_change?(conn) || is_nil(user.email_confirmed_at) do
      true ->
        send_confirmation_email(conn)

        conn
        |> put_flash(:info, "E-mail sent, please check your inbox.")
        |> redirect(to: Routes.pow_registration_path(conn, :edit))

      false ->
        conn
        |> put_flash(:info, "E-mail has already been confirmed.")
        |> redirect(to: Routes.pow_registration_path(conn, :edit))
    end
  end

  defp send_confirmation_email(conn) do
    current_user = Pow.Plug.current_user(conn)

    case ensure_confirmation_token(current_user) do
      {:ok, user} ->
        PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email(user, conn)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not generate confirmation email. Please try again.")
        |> redirect(to: Routes.pow_registration_path(conn, :edit))
    end
  end

  defp ensure_confirmation_token(%{email_confirmation_token: token} = user) when not is_nil(token) do
    {:ok, user}
  end

  defp ensure_confirmation_token(user) do
    attrs = %{
      email_confirmation_token: Pow.UUID.generate(),
      # Some existing users may not have this set; default to current email.
      unconfirmed_email: user.unconfirmed_email || user.email
    }

    user
    |> Changeset.change(attrs)
    |> Repo.update()
  end
end
