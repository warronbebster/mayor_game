defmodule MayorGameWeb.Pow.MailerTest do
  use MayorGame.DataCase
  import Swoosh.TestAssertions
  import MayorGame.Fixtures
  alias MayorGameWeb.Pow.Mailer

  test "account emails are sent to the user from app@fragile.city" do
    user = user_fixture()

    email = Mailer.cast(%{user: user, subject: "Confirm your email", text: "hi", html: "<p>hi</p>"})
    Mailer.deliver(email)

    assert_email_sent(
      subject: "Confirm your email",
      from: {"barron", "app@fragile.city"},
      to: [{user.nickname, user.email}]
    )
  end
end
