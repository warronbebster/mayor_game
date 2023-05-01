defmodule MayorGameWeb.RegistrationController do
  use MayorGameWeb, :controller

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
    user =
      if is_nil(Pow.Plug.current_user(conn).email_confirmation_token) do
        # config = Pow.Plug.fetch_config(conn)
        # IO.inspect(config, label: "config")
        # updated_conn = Pow.Plug.change_user(conn, %{unconfirmed_email: Pow.Plug.current_user(conn).email})
        # IO.inspect(updated_conn, label: "updated_conn")

        # I think this returns a conn

        Pow.Plug.current_user(conn)
        |> Map.put(:unconfirmed_email, Pow.Plug.current_user(conn).email)
        |> Map.put(:email_confirmation_token, "e058202b-cfhe-2422-b1ce-c64a66540249")

        # ok so can i just put any random strings here lol
        # apparently not
      else
        Pow.Plug.current_user(conn)
      end

    # MayorGame.Auth.update_user(Pow.Plug.current_user(conn), %{
    #   email_confirmation_token: "e058202b-cfhe-2422-b1ce-c64a66540249"
    # })
    # |> IO.inspect(label: "updated_user")

    # assigns = conn.assigns |> Map.put(:current_user, user)

    # conn = Map.put(conn, :assigns, assigns)

    # IO.inspect(conn, label: "conn in send_confirmtaiton_email")

    # secret = derive(conn, salt, key_opts(config))
    # Plug.Crypto.MessageVerifier.sign(message, secret)
    # Pow.Plug.MessageVerifier.sign(conn)

    # signing salt: Atom.to_string(__MODULE__)

    # risd token
    # e210402b-c3b3-4832-b1ce-c64a66540267

    # ok here's where we definitely need the email_confirmation_token in the conn in the user
    # token = PowEmailConfirmation.Plug.sign_confirmation_token(conn, user)
    # IO.inspect(token, label: "token")

    PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email(user, conn)
  end
end
