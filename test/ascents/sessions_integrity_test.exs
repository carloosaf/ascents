defmodule Ascents.SessionsIntegrityTest do
  use Ascents.IsolatedDataCase, async: false

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Ascents.SessionsFixtures

  alias Ascents.Gyms
  alias Ascents.Repo
  alias Ascents.Sessions

  test "direct session inserts cannot point at a non-session post" do
    scope = user_scope_fixture()
    gym = gym_fixture()
    {:ok, _membership} = Gyms.join_gym(scope, gym)

    %{rows: [[post_id]]} =
      Repo.query!(
        """
        INSERT INTO posts (
          body, post_type, visibility, gym_id, user_id, inserted_at, updated_at
        )
        VALUES ('ordinary post', 'normal', 'public', $1, $2, now(), now())
        RETURNING id
        """,
        [gym.id, scope.user.id]
      )

    assert_raise Postgrex.Error, ~r/sessions_post_integrity_fkey/, fn ->
      Repo.query!(
        """
        INSERT INTO sessions (
          title, started_at, visibility, post_type, user_id, gym_id, post_id,
          inserted_at, updated_at
        )
        VALUES ('Malformed', now(), 'public', 'session', $1, $2, $3, now(), now())
        """,
        [scope.user.id, gym.id, post_id]
      )
    end
  end

  test "direct grouped-ascent inserts cannot cross session ownership" do
    scope = user_scope_fixture()
    other_scope = user_scope_fixture()
    gym = gym_fixture()
    problem = boulder_problem_fixture(gym: gym)
    {:ok, _membership} = Gyms.join_gym(scope, gym)

    assert {:ok, %{session: session, post: post}} =
             Sessions.create_session(
               scope,
               gym,
               valid_session_attributes(ascents: [%{boulder_problem_id: problem.id}])
             )

    assert_raise Postgrex.Error,
                 ~r/ascents_post_integrity_fkey|ascents_session_integrity_fkey/,
                 fn ->
                   Repo.query!(
                     """
                     INSERT INTO ascents (
                       user_id, gym_id, boulder_problem_id, post_id, post_type, session_id,
                       climbed_at, grade_snapshot, grade_scale_snapshot, inserted_at, updated_at
                     )
                     VALUES ($1, $2, $3, $4, 'session', $5, $6, $7, $8, now(), now())
                     """,
                     [
                       other_scope.user.id,
                       gym.id,
                       problem.id,
                       post.id,
                       session.id,
                       session.started_at,
                       problem.grade,
                       gym.grade_scale
                     ]
                   )
                 end
  end

  test "direct malformed session graphs fail deferred mirror checks" do
    scope = user_scope_fixture()
    gym = gym_fixture()
    problem = boulder_problem_fixture(gym: gym)
    {:ok, _membership} = Gyms.join_gym(scope, gym)

    assert_raise Postgrex.Error, ~r/sessions_post_mirrors_check/, fn ->
      Repo.transaction(fn ->
        %{rows: [[post_id]]} =
          Repo.query!(
            """
            INSERT INTO posts (
              body, post_type, visibility, gym_id, user_id, inserted_at, updated_at
            )
            VALUES ('post notes', 'session', 'public', $1, $2, now(), now())
            RETURNING id
            """,
            [gym.id, scope.user.id]
          )

        %{rows: [[session_id]]} =
          Repo.query!(
            """
            INSERT INTO sessions (
              title, notes, started_at, visibility, post_type, user_id, gym_id, post_id,
              inserted_at, updated_at
            )
            VALUES (
              'Malformed mirrors', 'different notes', now(), 'public', 'session',
              $1, $2, $3, now(), now()
            )
            RETURNING id
            """,
            [scope.user.id, gym.id, post_id]
          )

        Repo.query!(
          """
          INSERT INTO ascents (
            user_id, gym_id, boulder_problem_id, post_id, post_type, session_id,
            climbed_at, grade_snapshot, grade_scale_snapshot, inserted_at, updated_at
          )
          SELECT
            user_id, gym_id, $1, post_id, 'session', id, started_at, $2, $3, now(), now()
          FROM sessions
          WHERE id = $4
          """,
          [problem.id, problem.grade, gym.grade_scale, session_id]
        )
      end)
    end
  end

  test "direct updates cannot drift session mirrors from their post" do
    %{session: session} = session_fixture()

    assert_raise Postgrex.Error, ~r/sessions_post_mirrors_check/, fn ->
      Repo.transaction(fn ->
        Repo.query!("UPDATE sessions SET visibility = 'friends' WHERE id = $1", [session.id])
        Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
      end)
    end
  end
end
