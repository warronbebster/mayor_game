# defmodule MayorGameWeb.Pow.Mailer do
#   use Pow.Phoenix.Mailer
#   require Logger

#   def cast(%{user: user, subject: subject, text: text, html: html, assigns: _assigns}) do
#     # Build email struct to be used in `process/1`

#     %{to: user.email, subject: subject, text: text, html: html}
#   end

#   def process(email) do
#     # Send email

#     Logger.debug("E-mail sent: #{inspect(email)}")
#   end
# end

defmodule MayorGameWeb.Pow.Mailer do
  use Pow.Phoenix.Mailer
  use Swoosh.Mailer, otp_app: :mayor_game

  import Swoosh.Email

  require Logger

  @impl true
  def cast(%{user: user, subject: subject, text: text, html: html}) do
    %Swoosh.Email{}
    |> to({user.nickname, user.email})
    |> from({"barron", "app@fragile.city"})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
    |> put_provider_option(:template_id, 4_465_570)
    |> put_provider_option(:template_error_deliver, true)
  end

  @impl true
  def process(email) do
    # An asynchronous process should be used here to prevent enumeration
    # attacks. Synchronous e-mail delivery can reveal whether a user already
    # exists in the system or not.

    Task.start(fn ->
      email
      |> deliver()
      |> log_warnings()
    end)

    :ok
  end

  defp log_warnings({:error, reason}) do
    Logger.warn("Mailer backend failed with: #{inspect(reason)}")
  end

  defp log_warnings({:ok, response}), do: {:ok, response}
end
