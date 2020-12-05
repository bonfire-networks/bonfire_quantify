defmodule Bonfire.Quantify.ConnCase do
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
  by setting `use MyApp.Web.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Bonfire.Quantify.ConnCase
      import Bonfire.Quantify.Test.ConnHelpers
      import Bonfire.Quantify.Test.FakeHelpers
      alias Bonfire.Quantify.Fake
      alias Bonfire.Quantify.Web.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint Bonfire.Quantify.Web.Endpoint
    end
  end

  setup tags do

    @repo Application.get_env(:bonfire_quantify, :repo_module)

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(@repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(@repo, {:shared, self()})
    end

    {:ok, []}
  end

end
