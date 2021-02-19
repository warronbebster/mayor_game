defmodule MayorGame.MayorAuthCheck do
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    current_city = get_session(conn, :info_id)
    # user = user_id && MayorGame.Auth.get_user!(user_id)
    # assign(conn, :current_user, user)
  end
end
