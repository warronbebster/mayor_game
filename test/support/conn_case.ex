defmodule MayorGameWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MayorGameWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MayorGameWeb.ConnCase

      alias MayorGameWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint MayorGameWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MayorGame.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(MayorGame.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Signs `user` in through the real session endpoint; the returned conn carries the session cookie."
  def log_in(conn, user) do
    conn
    |> Phoenix.ConnTest.dispatch(MayorGameWeb.Endpoint, :post, "/session", %{
      "user" => %{"email" => user.email, "password" => MayorGame.Fixtures.password()}
    })
    |> Phoenix.ConnTest.recycle()
  end
end
