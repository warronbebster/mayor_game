defmodule MayorGame.MayorAuthCheck do
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    current_city = get_session(conn, :info_id)
    IO.puts(current_city)
    # user = user_id && Rumbl.Accounts.get_user(user_id)
    # assign(conn, :current_user, user)
  end
end
