defmodule Ascents.SessionsConcurrencyTest do
  use Ascents.IsolatedDataCase, async: false

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Ascents.SessionsFixtures

  alias Ascents.Ascents.Ascent
  alias Ascents.Feed.Post
  alias Ascents.Gyms
  alias Ascents.Gyms.GymMembership
  alias Ascents.Repo
  alias Ascents.Sessions
  alias Ascents.Sessions.Session

  test "membership removal serializes before authorization", %{isolated_repo: repo} do
    parent = self()
    supervisor = start_supervised!({Task.Supervisor, name: nil})
    scope = user_scope_fixture()
    gym = gym_fixture()
    problem = boulder_problem_fixture(gym: gym)
    {:ok, membership} = Gyms.join_gym(scope, gym)

    removal_task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        Repo.put_dynamic_repo(repo)

        Repo.transaction(fn ->
          GymMembership
          |> Repo.get!(membership.id)
          |> Repo.delete!()

          send(parent, :membership_delete_locked)

          receive do
            :commit_membership_removal -> :ok
          end
        end)
      end)

    assert_receive :membership_delete_locked

    create_task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        Repo.put_dynamic_repo(repo)

        Repo.checkout(fn ->
          send(parent, {:create_backend, backend_pid()})

          Sessions.create_session(
            scope,
            gym,
            valid_session_attributes(ascents: [%{boulder_problem_id: problem.id}])
          )
        end)
      end)

    assert_receive {:create_backend, create_backend}
    await_lock_wait!(create_backend)
    send(removal_task.pid, :commit_membership_removal)

    assert {:ok, _membership} = Task.await(removal_task)
    assert {:error, :unauthorized} = Task.await(create_task)
    assert Repo.aggregate(Session, :count) == 0
    assert Repo.aggregate(Post, :count) == 0
    assert Repo.aggregate(Ascent, :count) == 0
  end

  test "route archival serializes before active-route resolution", %{isolated_repo: repo} do
    parent = self()
    supervisor = start_supervised!({Task.Supervisor, name: nil})
    scope = user_scope_fixture()
    gym = gym_fixture()
    problem = boulder_problem_fixture(gym: gym)
    {:ok, _membership} = Gyms.join_gym(scope, gym)

    archive_task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        Repo.put_dynamic_repo(repo)

        Repo.transaction(fn ->
          problem
          |> Ecto.Changeset.change(
            active: false,
            archived_at: ~U[2026-06-24 12:00:00Z]
          )
          |> Repo.update!()

          send(parent, :route_archive_locked)

          receive do
            :commit_route_archive -> :ok
          end
        end)
      end)

    assert_receive :route_archive_locked

    create_task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        Repo.put_dynamic_repo(repo)

        Repo.checkout(fn ->
          send(parent, {:create_backend, backend_pid()})

          Sessions.create_session(
            scope,
            gym,
            valid_session_attributes(ascents: [%{boulder_problem_id: problem.id}])
          )
        end)
      end)

    assert_receive {:create_backend, create_backend}
    await_lock_wait!(create_backend)
    send(archive_task.pid, :commit_route_archive)

    assert {:ok, _problem} = Task.await(archive_task)
    assert {:error, changeset} = Task.await(create_task)
    assert %{ascents: ["row 1 references an archived route"]} = errors_on(changeset)
    assert Repo.aggregate(Session, :count) == 0
    assert Repo.aggregate(Post, :count) == 0
    assert Repo.aggregate(Ascent, :count) == 0
  end

  defp backend_pid do
    [[backend_pid]] = Repo.query!("SELECT pg_backend_pid()").rows
    backend_pid
  end

  defp await_lock_wait!(backend_pid, attempts \\ 200)

  defp await_lock_wait!(_backend_pid, 0) do
    flunk("concurrent session creation never waited on the expected row lock")
  end

  defp await_lock_wait!(backend_pid, attempts) do
    case Repo.query!(
           """
           SELECT wait_event_type
           FROM pg_stat_activity
           WHERE pid = $1
           """,
           [backend_pid]
         ).rows do
      [["Lock"]] -> :ok
      _rows -> await_lock_wait!(backend_pid, attempts - 1)
    end
  end
end
