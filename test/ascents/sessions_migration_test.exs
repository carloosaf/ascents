defmodule Ascents.SessionsMigrationTest do
  use Ascents.IsolatedDataCase, async: false

  @moduletag :skip_migrations

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Ascents.SessionsFixtures

  alias Ascents.Gyms
  alias Ascents.Repo
  alias Ascents.Sessions

  @before_sessions 20_260_624_115_105

  setup do
    compiler_options = Code.compiler_options(ignore_module_conflict: true)
    on_exit(fn -> Code.compiler_options(compiler_options) end)
  end

  test "migrates up, creates a multi-ascent session, and safely migrates down",
       %{isolated_repo: repo} do
    migrations_path = Ecto.Migrator.migrations_path(Repo)

    Ecto.Migrator.run(
      Repo,
      migrations_path,
      :up,
      to: @before_sessions,
      dynamic_repo: repo,
      log: false
    )

    scope = user_scope_fixture()
    gym = gym_fixture()
    standalone_problem = boulder_problem_fixture(gym: gym)
    first_session_problem = boulder_problem_fixture(gym: gym, title: "Session one")
    second_session_problem = boulder_problem_fixture(gym: gym, title: "Session two")
    {:ok, _membership} = Gyms.join_gym(scope, gym)

    now = ~U[2026-06-24 12:00:00Z]

    %{rows: [[standalone_post_id]]} =
      Repo.query!(
        """
        INSERT INTO posts (
          body, post_type, visibility, gym_id, user_id, boulder_problem_id,
          inserted_at, updated_at
        )
        VALUES ($1, 'ascent', 'public', $2, $3, $4, $5, $5)
        RETURNING id
        """,
        ["Standalone ascent", gym.id, scope.user.id, standalone_problem.id, now]
      )

    Repo.query!(
      """
      INSERT INTO ascents (
        user_id, gym_id, boulder_problem_id, post_id, climbed_at,
        grade_snapshot, grade_scale_snapshot, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $5, $5)
      """,
      [
        scope.user.id,
        gym.id,
        standalone_problem.id,
        standalone_post_id,
        now,
        standalone_problem.grade,
        gym.grade_scale
      ]
    )

    Ecto.Migrator.run(
      Repo,
      migrations_path,
      :up,
      all: true,
      dynamic_repo: repo,
      log: false
    )

    assert {:ok, %{post: session_post, ascents: [_first, _second]}} =
             Sessions.create_session(
               scope,
               gym,
               valid_session_attributes(
                 ascents: [
                   %{boulder_problem_id: first_session_problem.id},
                   %{boulder_problem_id: second_session_problem.id}
                 ]
               )
             )

    assert [[2]] =
             Repo.query!("SELECT count(*) FROM ascents WHERE post_id = $1", [session_post.id]).rows

    assert [20_260_624_120_920] =
             Ecto.Migrator.run(
               Repo,
               migrations_path,
               :down,
               step: 1,
               dynamic_repo: repo,
               log: false
             )

    assert [[0]] = Repo.query!("SELECT count(*) FROM sessions").rows
    assert [[0]] = Repo.query!("SELECT count(*) FROM posts WHERE post_type = 'session'").rows
    assert [[1]] = Repo.query!("SELECT count(*) FROM ascents").rows

    assert [[standalone_post_id]] =
             Repo.query!("SELECT post_id FROM ascents ORDER BY id").rows

    refute column_exists?("ascents", "session_id")
    refute column_exists?("ascents", "post_type")

    assert_raise Postgrex.Error, fn ->
      Repo.query!(
        """
        INSERT INTO ascents (
          user_id, gym_id, boulder_problem_id, post_id, climbed_at,
          grade_snapshot, grade_scale_snapshot, inserted_at, updated_at
        )
        SELECT
          user_id, gym_id, boulder_problem_id, post_id, climbed_at,
          grade_snapshot, grade_scale_snapshot, inserted_at, updated_at
        FROM ascents
        WHERE post_id = $1
        """,
        [standalone_post_id]
      )
    end

    assert [20_260_624_120_917] =
             Ecto.Migrator.run(
               Repo,
               migrations_path,
               :down,
               step: 1,
               dynamic_repo: repo,
               log: false
             )

    refute table_exists?("sessions")
  end

  defp table_exists?(table) do
    Repo.query!(
      """
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = current_schema()
          AND table_name = $1
      )
      """,
      [table]
    ).rows == [[true]]
  end

  defp column_exists?(table, column) do
    Repo.query!(
      """
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = $1
          AND column_name = $2
      )
      """,
      [table, column]
    ).rows == [[true]]
  end
end
