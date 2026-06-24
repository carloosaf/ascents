defmodule Ascents.IsolatedDataCase do
  @moduledoc """
  Runs database tests against a committed temporary PostgreSQL schema.

  Unlike the SQL sandbox, the isolated repo has a real connection pool, so
  concurrent tests can exercise row locks on separate database connections.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Ascents.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Ascents.DataCase
    end
  end

  setup tags do
    schema = "isolated_#{System.unique_integer([:positive])}"

    connection_options =
      Keyword.take(Ascents.Repo.config(), [
        :database,
        :hostname,
        :password,
        :port,
        :socket_options,
        :ssl,
        :ssl_opts,
        :username
      ])

    admin =
      start_supervised!(
        {Postgrex, connection_options},
        id: {:isolated_database_admin, schema}
      )

    Postgrex.query!(admin, ~s(CREATE SCHEMA "#{schema}"), [])
    Supervisor.stop(admin)

    repo =
      start_supervised!(
        {Ascents.Repo,
         connection_options ++
           [
             name: nil,
             pool: DBConnection.ConnectionPool,
             pool_size: 3,
             parameters: [search_path: "#{schema},public"],
             log: false
           ]},
        id: {:isolated_repo, schema}
      )

    Ascents.Repo.put_dynamic_repo(repo)

    unless tags[:skip_migrations] do
      compiler_options = Code.compiler_options(ignore_module_conflict: true)

      try do
        Ecto.Migrator.run(
          Ascents.Repo,
          Ecto.Migrator.migrations_path(Ascents.Repo),
          :up,
          all: true,
          dynamic_repo: repo,
          log: false
        )
      after
        Code.compiler_options(compiler_options)
      end
    end

    on_exit(fn ->
      Ascents.Repo.put_dynamic_repo(Ascents.Repo)

      {:ok, cleanup_connection} = Postgrex.start_link(connection_options)
      Postgrex.query!(cleanup_connection, ~s(DROP SCHEMA IF EXISTS "#{schema}" CASCADE), [])
      GenServer.stop(cleanup_connection)
    end)

    {:ok, isolated_repo: repo, isolated_schema: schema}
  end
end
