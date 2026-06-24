defmodule Ascents.GymsVerificationConcurrencyTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures

  alias Ascents.Accounts.User
  alias Ascents.Gyms
  alias Ascents.Gyms.Gym
  alias Ascents.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox

  @request_note "I operate this gym and can confirm through our official website."

  setup do
    previous_platform_admin_emails =
      Application.get_env(:ascents, :platform_admin_emails, :not_configured)

    platform_admin_emails = [
      "platform-admin@example.com",
      "second-platform-admin@example.com"
    ]

    Application.put_env(:ascents, :platform_admin_emails, platform_admin_emails)

    %{gym: gym, owner_scope: owner_scope, admin_scopes: admin_scopes, user_ids: user_ids} =
      unboxed(fn ->
        owner_scope = user_scope_fixture()
        {:ok, gym} = Gyms.create_gym(owner_scope, valid_gym_attributes())

        admin_scopes =
          Enum.map(platform_admin_emails, fn email ->
            user_scope_fixture(user_fixture(email: email))
          end)

        %{
          gym: gym,
          owner_scope: owner_scope,
          admin_scopes: admin_scopes,
          user_ids: [owner_scope.user.id | Enum.map(admin_scopes, & &1.user.id)]
        }
      end)

    on_exit(fn ->
      unboxed(fn ->
        Repo.delete_all(from gym in Gym, where: gym.id == ^gym.id)
        Repo.delete_all(from user in User, where: user.id in ^user_ids)
      end)

      restore_platform_admin_emails(previous_platform_admin_emails)
    end)

    {:ok, gym: gym, owner_scope: owner_scope, admin_scopes: admin_scopes}
  end

  test "competing requests use separate connections and serialize on the gym row", %{
    gym: gym,
    owner_scope: owner_scope
  } do
    request = fn ->
      Gyms.request_verification(owner_scope, gym, %{note: @request_note})
    end

    assert_locked_transition(gym, request, request)

    pending_gym = unboxed(fn -> Gyms.get_gym!(gym.id) end)
    assert pending_gym.verification_status == "pending"
    assert pending_gym.verification_requested_by_user_id == owner_scope.user.id
  end

  test "competing approvals use separate connections and serialize on the gym row", %{
    gym: gym,
    owner_scope: owner_scope,
    admin_scopes: [first_admin_scope, second_admin_scope]
  } do
    pending_gym =
      unboxed(fn ->
        {:ok, pending_gym} =
          Gyms.request_verification(owner_scope, gym, %{note: @request_note})

        pending_gym
      end)

    first_approval = fn ->
      Gyms.approve_verification(first_admin_scope, pending_gym, %{
        note: "Reviewed by the first platform administrator."
      })
    end

    second_approval = fn ->
      Gyms.approve_verification(second_admin_scope, pending_gym, %{
        note: "Reviewed by the second platform administrator."
      })
    end

    assert_locked_transition(gym, first_approval, second_approval)

    verified_gym = unboxed(fn -> Gyms.get_gym!(gym.id) end)
    assert verified_gym.verification_status == "verified"
    assert verified_gym.verified_by_user_id == first_admin_scope.user.id
  end

  test "competing revocations use separate connections and serialize on the gym row", %{
    gym: gym,
    owner_scope: owner_scope,
    admin_scopes: [first_admin_scope, second_admin_scope]
  } do
    verified_gym =
      unboxed(fn ->
        {:ok, pending_gym} =
          Gyms.request_verification(owner_scope, gym, %{note: @request_note})

        {:ok, verified_gym} =
          Gyms.approve_verification(first_admin_scope, pending_gym, %{
            note: "Verified before the concurrent revocation test."
          })

        verified_gym
      end)

    first_revoke = fn -> Gyms.revoke_verification(first_admin_scope, verified_gym) end
    second_revoke = fn -> Gyms.revoke_verification(second_admin_scope, verified_gym) end

    assert_locked_transition(gym, first_revoke, second_revoke)

    community_gym = unboxed(fn -> Gyms.get_gym!(gym.id) end)
    assert community_gym.verification_status == "community"
    assert community_gym.verification_requested_at == nil
    assert community_gym.verified_at == nil
  end

  defp assert_locked_transition(gym, first_transition, competing_transition) do
    parent = self()
    task_supervisor = start_supervised!(Task.Supervisor)

    lock_holder =
      Task.Supervisor.async_nolink(task_supervisor, fn ->
        with_owned_connection(fn ->
          Repo.transact(fn ->
            Gym
            |> where([locked_gym], locked_gym.id == ^gym.id)
            |> lock("FOR UPDATE")
            |> Repo.one!()

            send(parent, {:gym_lock_acquired, self(), database_connection_pid()})

            receive do
              :run_first_transition -> first_transition.()
            end
          end)
        end)
      end)

    assert_receive {:gym_lock_acquired, lock_holder_pid, lock_holder_connection_pid}

    competitor =
      Task.Supervisor.async_nolink(task_supervisor, fn ->
        with_owned_connection(fn ->
          connection_pid = database_connection_pid()
          send(parent, {:competitor_ready, self(), connection_pid})

          receive do
            :run_competing_transition -> competing_transition.()
          end
        end)
      end)

    assert_receive {:competitor_ready, competitor_pid, competitor_connection_pid}
    refute lock_holder_connection_pid == competitor_connection_pid

    send(competitor_pid, :run_competing_transition)
    assert_connection_waiting_on_lock(competitor_connection_pid)
    send(lock_holder_pid, :run_first_transition)

    assert {:ok, %Gym{}} = Task.await(lock_holder)
    assert {:error, :invalid_transition} = Task.await(competitor)
  end

  defp with_owned_connection(fun) do
    :ok = Sandbox.checkout(Repo, sandbox: false)

    try do
      fun.()
    after
      :ok = Sandbox.checkin(Repo)
    end
  end

  defp database_connection_pid do
    %{rows: [[connection_pid]]} = SQL.query!(Repo, "SELECT pg_backend_pid()", [])
    connection_pid
  end

  defp assert_connection_waiting_on_lock(connection_pid) do
    deadline = System.monotonic_time(:millisecond) + 2_000

    unboxed(fn ->
      wait_for_lock(connection_pid, deadline)
    end)
  end

  defp wait_for_lock(connection_pid, deadline) do
    %{rows: rows} =
      SQL.query!(
        Repo,
        """
        SELECT wait_event_type
        FROM pg_stat_activity
        WHERE pid = $1
        """,
        [connection_pid]
      )

    case rows do
      [["Lock"]] ->
        :ok

      _rows ->
        if System.monotonic_time(:millisecond) < deadline do
          wait_for_lock(connection_pid, deadline)
        else
          flunk("competing database connection never waited on the gym row lock")
        end
    end
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)

  defp restore_platform_admin_emails(:not_configured) do
    Application.delete_env(:ascents, :platform_admin_emails)
  end

  defp restore_platform_admin_emails(emails) do
    Application.put_env(:ascents, :platform_admin_emails, emails)
  end
end
