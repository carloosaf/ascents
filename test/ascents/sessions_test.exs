defmodule Ascents.SessionsTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.AscentsFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Ascents.SessionsFixtures

  alias Ascents.Ascents, as: AscentLogs
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed
  alias Ascents.Feed.Post
  alias Ascents.Gyms
  alias Ascents.Repo
  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Sessions
  alias Ascents.Sessions.Session

  describe "change_session/1" do
    test "defaults visibility and validates at least one ascent row" do
      changeset =
        Sessions.change_session(%{
          title: "Evening session",
          started_at: "2026-06-23",
          ascents: [%{boulder_problem_id: 123}]
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :visibility) == "public"
      assert Ecto.Changeset.get_field(changeset, :started_at) == ~U[2026-06-23 00:00:00Z]

      empty_changeset =
        Sessions.change_session(%{
          title: "No sends",
          started_at: "2026-06-23",
          ascents: []
        })

      assert %{ascents: ["should have at least 1 item(s)"]} = errors_on(empty_changeset)
    end
  end

  describe "create_session/3" do
    test "creates one session post and multiple stats-compatible ascents" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(grade_scale: "french")
      first_problem = boulder_problem_fixture(gym: gym, title: "Blue Arete", grade: "6A")
      second_problem = boulder_problem_fixture(gym: gym, title: "Red Roof", grade: "6B")
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:ok, %{session: session, post: post, ascents: ascents}} =
               Sessions.create_session(
                 scope,
                 gym,
                 valid_session_attributes(%{
                   title: "  Power night  ",
                   notes: "  Two good sends.  ",
                   started_at: "2026-06-23T18:30",
                   visibility: "friends",
                   ascents: [
                     %{boulder_problem_id: first_problem.id},
                     %{boulder_problem_id: second_problem.id}
                   ]
                 })
               )

      assert %Session{} = session
      assert session.title == "Power night"
      assert session.notes == "Two good sends."
      assert session.started_at == ~U[2026-06-23 18:30:00Z]
      assert session.image_object_key == "sessions/1/training.jpg"
      assert session.visibility == "friends"
      assert session.user_id == user.id
      assert session.gym_id == gym.id
      assert session.post_id == post.id
      assert session.user.id == user.id
      assert session.gym.id == gym.id
      assert session.post.id == post.id

      assert %Post{} = post
      assert post.post_type == "session"
      assert post.body == "Two good sends."
      assert post.image_object_key == session.image_object_key
      assert post.visibility == "friends"
      assert post.user_id == user.id
      assert post.gym_id == gym.id
      assert post.boulder_problem_id == nil
      assert post.session.id == session.id

      assert Enum.map(ascents, & &1.boulder_problem_id) == [
               first_problem.id,
               second_problem.id
             ]

      assert Enum.all?(ascents, fn ascent ->
               ascent.user_id == user.id and
                 ascent.gym_id == gym.id and
                 ascent.post_id == post.id and
                 ascent.session_id == session.id and
                 ascent.climbed_at == session.started_at and
                 ascent.grade_scale_snapshot == "french" and
                 Ecto.assoc_loaded?(ascent.boulder_problem)
             end)

      assert Enum.map(ascents, & &1.grade_snapshot) == ["6A", "6B"]

      assert {:ok, stats} = AscentLogs.get_user_stats(scope, user, today: ~D[2026-06-24])
      assert stats.total_ascents == 2
      assert stats.unique_gyms == 1
      assert stats.unique_routes == 2

      friend = user_fixture()
      friend_scope = user_scope_fixture(friend)
      unrelated_scope = user_scope_fixture()
      accepted_friendship_fixture(requester: user, recipient: friend)

      assert Feed.list_gym_posts(gym) == []
      assert Feed.list_gym_posts(gym, unrelated_scope) == []

      assert [feed_post] = Feed.list_gym_posts(gym, scope)
      assert feed_post.id == post.id
      assert feed_post.session.id == session.id

      assert Enum.map(feed_post.session.ascents, & &1.boulder_problem_id) ==
               Enum.map(ascents, & &1.boulder_problem_id)

      assert [friend_feed_post] = Feed.list_gym_posts(gym, friend_scope)
      assert friend_feed_post.id == post.id
      assert friend_feed_post.session.id == session.id
    end

    test "allows blank optional notes and image while preserving the session date" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:ok, %{session: session, post: post, ascents: [ascent]}} =
               Sessions.create_session(scope, gym, %{
                 title: "Lunch break",
                 notes: "   ",
                 image_object_key: "",
                 started_at: ~D[2026-06-22],
                 visibility: "public",
                 ascents: [%{boulder_problem_id: problem.id}]
               })

      assert session.notes == nil
      assert session.image_object_key == nil
      assert session.started_at == ~U[2026-06-22 00:00:00Z]
      assert post.body == nil
      assert post.image_object_key == nil
      assert ascent.climbed_at == session.started_at

      assert [feed_post] = Feed.list_gym_posts(gym)
      assert feed_post.id == post.id
      assert feed_post.session.id == session.id
    end

    test "requires authenticated gym membership" do
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      attrs = valid_session_attributes(ascents: [%{boulder_problem_id: problem.id}])

      assert Sessions.create_session(user_scope_fixture(), gym, attrs) ==
               {:error, :unauthorized}

      assert Sessions.create_session(nil, gym, attrs) == {:error, :unauthorized}
    end

    test "rejects routes from another gym and rolls back every row" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      valid_problem = boulder_problem_fixture(gym: gym)
      other_problem = boulder_problem_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} =
               Sessions.create_session(
                 scope,
                 gym,
                 valid_session_attributes(
                   ascents: [
                     %{boulder_problem_id: valid_problem.id},
                     %{boulder_problem_id: other_problem.id}
                   ]
                 )
               )

      assert %{ascents: ["row 2 references a route outside this gym"]} = errors_on(changeset)
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Post, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
    end

    test "rejects archived routes and rolls back every row" do
      scope = user_scope_fixture()
      admin_scope = user_scope_fixture()
      gym = gym_fixture()
      role_membership_fixture(gym, "admin", scope: admin_scope)
      active_problem = boulder_problem_fixture(gym: gym, scope: admin_scope)
      archived_problem = boulder_problem_fixture(gym: gym, scope: admin_scope)

      {:ok, archived_problem} =
        ClimbingRoutes.archive_boulder_problem(admin_scope, gym, archived_problem)

      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} =
               Sessions.create_session(
                 scope,
                 gym,
                 valid_session_attributes(
                   ascents: [
                     %{boulder_problem_id: active_problem.id},
                     %{boulder_problem_id: archived_problem.id}
                   ]
                 )
               )

      assert %{ascents: ["row 2 references an archived route"]} = errors_on(changeset)
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Post, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
    end

    test "rolls back the post, session, and prior ascents when a later insert is invalid" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      valid_problem = boulder_problem_fixture(gym: gym)
      invalid_problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      {1, nil} =
        from(problem in Ascents.Routes.BoulderProblem, where: problem.id == ^invalid_problem.id)
        |> Repo.update_all(set: [grade: String.duplicate("V", 33)])

      assert {:error, changeset} =
               Sessions.create_session(
                 scope,
                 gym,
                 valid_session_attributes(
                   ascents: [
                     %{boulder_problem_id: valid_problem.id},
                     %{boulder_problem_id: invalid_problem.id}
                   ]
                 )
               )

      assert %{grade_snapshot: ["should be at most 32 character(s)"]} = errors_on(changeset)
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Post, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
    end

    test "sets all ownership IDs programmatically" do
      user = user_fixture()
      other_user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      other_gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:ok, %{session: session, post: post, ascents: [ascent]}} =
               Sessions.create_session(
                 scope,
                 gym,
                 valid_session_attributes(%{
                   user_id: other_user.id,
                   gym_id: other_gym.id,
                   post_id: -1,
                   ascents: [
                     %{
                       boulder_problem_id: problem.id,
                       user_id: other_user.id,
                       gym_id: other_gym.id,
                       post_id: -1,
                       session_id: -1
                     }
                   ]
                 })
               )

      assert {session.user_id, session.gym_id, session.post_id} ==
               {user.id, gym.id, post.id}

      assert {post.user_id, post.gym_id} == {user.id, gym.id}

      assert {ascent.user_id, ascent.gym_id, ascent.post_id, ascent.session_id} ==
               {user.id, gym.id, post.id, session.id}
    end

    test "validates visibility and ascent rows before writing" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, visibility_changeset} =
               Sessions.create_session(
                 scope,
                 gym,
                 valid_session_attributes(visibility: "private", ascents: [%{}])
               )

      assert %{visibility: ["is invalid"], ascents: ["must contain valid route selections"]} =
               errors_on(visibility_changeset)

      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Post, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
    end
  end

  describe "migration compatibility" do
    test "standalone ascent posts keep their unique post link" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      %{post: post, ascent: ascent} =
        ascent_post_fixture(scope: scope, gym: gym, problem: problem)

      assert ascent.post_id == post.id
      assert ascent.session_id == nil

      duplicate =
        %Ascent{
          user_id: scope.user.id,
          gym_id: gym.id,
          boulder_problem_id: problem.id,
          post_id: post.id
        }
        |> Ascent.changeset(%{
          climbed_at: ~U[2026-06-24 10:00:00Z],
          grade_snapshot: problem.grade,
          grade_scale_snapshot: gym.grade_scale
        })

      assert {:error, changeset} = Repo.insert(duplicate)
      assert %{post_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "normal, ascent, and session post types satisfy the database constraint" do
      assert Post.post_types() == ~w(normal ascent session)

      for post_type <- Post.post_types() do
        changeset =
          %Post{gym_id: 1, user_id: 1, post_type: post_type}
          |> Post.changeset(%{
            body: if(post_type == "normal", do: "Body", else: nil),
            visibility: "public"
          })

        if post_type == "ascent" do
          refute changeset.valid?
          assert %{boulder_problem_id: ["can't be blank"]} = errors_on(changeset)
        else
          assert changeset.valid?
        end
      end
    end
  end

  describe "session post deletion" do
    test "atomically removes a session from feeds and ascent stats with one timestamp" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()

      problems = [
        boulder_problem_fixture(gym: gym, title: "Delete one"),
        boulder_problem_fixture(gym: gym, title: "Delete two")
      ]

      %{session: session, post: post, ascents: ascents} =
        session_fixture(scope: scope, gym: gym, problems: problems)

      assert {:ok, deleted_post} = Feed.delete_post(scope, gym, post)
      deleted_session = Repo.get!(Session, session.id)
      deleted_ascents = Repo.all(from(ascent in Ascent, where: ascent.session_id == ^session.id))

      assert deleted_post.deleted_at
      assert deleted_session.deleted_at == deleted_post.deleted_at

      assert Enum.map(deleted_ascents, & &1.deleted_at) ==
               List.duplicate(deleted_post.deleted_at, length(ascents))

      assert Feed.list_gym_posts(gym) == []
      assert Feed.list_user_posts(user) == []

      assert {:ok, stats} = AscentLogs.get_user_stats(scope, user, today: ~D[2026-06-24])
      assert stats.total_ascents == 0
      assert stats.unique_gyms == 0
      assert stats.unique_routes == 0
    end

    test "rolls back post and session deletion when grouped ascent deletion fails" do
      scope = user_scope_fixture()
      gym = gym_fixture()

      %{session: session, post: post, ascents: [ascent]} =
        session_fixture(scope: scope, gym: gym)

      Repo.query!("""
      CREATE FUNCTION reject_session_ascent_soft_delete()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'forced grouped ascent failure';
      END;
      $$
      """)

      Repo.query!("""
      CREATE TRIGGER reject_session_ascent_soft_delete
      BEFORE UPDATE OF deleted_at ON ascents
      FOR EACH ROW
      WHEN (OLD.session_id IS NOT NULL AND NEW.deleted_at IS NOT NULL)
      EXECUTE FUNCTION reject_session_ascent_soft_delete()
      """)

      assert_raise Postgrex.Error, ~r/forced grouped ascent failure/, fn ->
        Feed.delete_post(scope, gym, post)
      end

      assert Repo.get!(Post, post.id).deleted_at == nil
      assert Repo.get!(Session, session.id).deleted_at == nil
      assert Repo.get!(Ascent, ascent.id).deleted_at == nil
      assert [visible_post] = Feed.list_gym_posts(gym)
      assert visible_post.id == post.id
    end
  end
end
