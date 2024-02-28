# defmodule MayorGameWeb.ConfirmationController do
#   use MayorGameWeb, :controller

#   alias Plug.Conn

#   @spec show(Conn.t(), map()) :: Conn.t()
#   def show(conn, %{"id" => token}) do
#     case PowEmailConfirmation.Plug.load_user_by_token(conn, token) do
#       {:error, conn} ->
#         conn
#         |> put_status(401)
#         |> json(%{error: %{status: 401, message: "Invalid confirmation code"}})

#       {:ok, conn} ->
#         # Extra bit starting
#         IO.inspect("ayy email confirm thingy")

#         case PowEmailConfirmation.Plug.confirm_email(conn, %{}) do
#           {:ok, _, conn} ->
#             conn
#             |> json(%{success: %{message: "Email confirmed"}})

#           {:error, _, conn} ->
#             conn
#             |> put_status(401)
#             |> json(%{error: %{status: 401, message: "Invalid confirmation code"}})
#         end

#         # Extra bit ending
#     end
#   end
# end
