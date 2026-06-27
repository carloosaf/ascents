defmodule Ascents.AscentsTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.AscentsFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures

  alias Ascents.Ascents, as: AscentLogs
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed
  alias Ascents.Feed.Post
  alias Ascents.Gyms
  alias Ascents.Repo
  alias Ascents.Routes, as: ClimbingRoutes

  describe "change_ascent_post/1" do
    test "returns an ascent post changeset" do
      assert %Ecto.Changeset{} = AscentLogs.change_ascent_post()
    end
  end

  describe "create_ascent_post/3" do
    test "creates a linked post and ascent with grade snapshots" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(grade_scale: "french")
      problem = boulder_problem_fixture(gym: gym, grade: "6A")
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:ok, %{post: post, ascent: ascent}} =
               AscentLogs.create_ascent_post(
                 scope,
                 gym,
                 valid_ascent_post_attributes(
                   body: "",
                   boulder_problem_id: problem.id,
                   climbed_at: "2026-06-11T10:30"
                 )
               )

      assert %Post{} = post
      assert post.post_type == "ascent"
      assert post.body == nil
      assert post.gym_id == gym.id
      assert post.user_id == user.id
      assert post.boulder_problem_id == problem.id
      assert post.visibility == "public"

      assert %Ascent{} = ascent
      assert ascent.post_id == post.id
      assert ascent.gym_id == gym.id
      assert ascent.user_id == user.id
      assert ascent.boulder_problem_id == problem.id
      assert ascent.grade_snapshot == "6A"
      assert ascent.grade_scale_snapshot == "french"
      assert ascent.climbed_at == ~U[2026-06-11 10:30:00Z]
    end

    test "accepts public, friends, and private visibility values" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      for visibility <- ~w(public friends private) do
        assert {:ok, %{post: post}} =
                 AscentLogs.create_ascent_post(
                   scope,
                   gym,
                   valid_ascent_post_attributes(
                     boulder_problem_id: problem.id,
                     visibility: visibility
                   )
                 )

        assert post.visibility == visibility
        assert post.gym_id == gym.id
      end
    end

    test "rejects invalid visibility values" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} =
               AscentLogs.create_ascent_post(
                 scope,
                 gym,
                 valid_ascent_post_attributes(
                   boulder_problem_id: problem.id,
                   visibility: "hidden"
                 )
               )

      assert %{visibility: ["is invalid"]} = errors_on(changeset)
    end

    test "keeps private ascents visible only to their author" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      viewer_scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      {:ok, _membership} = Gyms.join_gym(viewer_scope, gym)

      assert {:ok, %{post: private_post}} =
               AscentLogs.create_ascent_post(
                 scope,
                 gym,
                 valid_ascent_post_attributes(
                   boulder_problem_id: problem.id,
                   visibility: "private"
                 )
               )

      assert Feed.list_gym_posts(gym) == []
      assert Enum.map(Feed.list_gym_posts(gym, scope), & &1.id) == [private_post.id]
      assert Feed.list_gym_posts(gym, viewer_scope) == []
      assert Enum.map(Feed.list_home_posts(scope), & &1.id) == [private_post.id]
      assert Feed.list_home_posts(viewer_scope) == []
      assert Enum.map(Feed.list_user_posts(user, scope), & &1.id) == [private_post.id]
      assert Feed.list_user_posts(user, viewer_scope) == []
    end

    test "keeps friends-only ascents visible to the author and accepted friends" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      friend = user_fixture()
      friend_scope = user_scope_fixture(friend)
      unrelated_scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      {:ok, _membership} = Gyms.join_gym(friend_scope, gym)
      {:ok, _membership} = Gyms.join_gym(unrelated_scope, gym)
      accepted_friendship_fixture(requester: user, recipient: friend)

      assert {:ok, %{post: friends_post}} =
               AscentLogs.create_ascent_post(
                 scope,
                 gym,
                 valid_ascent_post_attributes(
                   boulder_problem_id: problem.id,
                   visibility: "friends"
                 )
               )

      assert Feed.list_gym_posts(gym) == []
      assert Feed.list_gym_posts(gym, unrelated_scope) == []
      assert Enum.map(Feed.list_gym_posts(gym, scope), & &1.id) == [friends_post.id]
      assert Enum.map(Feed.list_gym_posts(gym, friend_scope), & &1.id) == [friends_post.id]
      assert Feed.list_home_posts(unrelated_scope) == []
      assert Enum.map(Feed.list_home_posts(friend_scope), & &1.id) == [friends_post.id]
      assert Feed.list_user_posts(user, unrelated_scope) == []
      assert Enum.map(Feed.list_user_posts(user, friend_scope), & &1.id) == [friends_post.id]
    end

    test "requires gym membership" do
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      scope = user_scope_fixture()

      assert AscentLogs.create_ascent_post(
               scope,
               gym,
               valid_ascent_post_attributes(boulder_problem_id: problem.id)
             ) == {:error, :unauthorized}
    end

    test "validates route and climbed datetime" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} =
               AscentLogs.create_ascent_post(scope, gym, %{
                 body: "",
                 climbed_at: "",
                 boulder_problem_id: ""
               })

      assert %{boulder_problem_id: ["can't be blank"], climbed_at: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "rejects archived routes" do
      scope = user_scope_fixture()
      admin_scope = user_scope_fixture()
      gym = gym_fixture()
      role_membership_fixture(gym, "admin", scope: admin_scope)
      problem = boulder_problem_fixture(gym: gym, scope: admin_scope)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      {:ok, archived_problem} = ClimbingRoutes.archive_boulder_problem(admin_scope, gym, problem)

      assert {:error, changeset} =
               AscentLogs.create_ascent_post(
                 scope,
                 gym,
                 valid_ascent_post_attributes(boulder_problem_id: archived_problem.id)
               )

      assert %{boulder_problem_id: ["is archived"]} = errors_on(changeset)
    end

    test "rejects routes from another gym" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      other_problem = boulder_problem_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} =
               AscentLogs.create_ascent_post(
                 scope,
                 gym,
                 valid_ascent_post_attributes(boulder_problem_id: other_problem.id)
               )

      assert %{boulder_problem_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "post deletion" do
    test "soft-deletes the linked ascent when the ascent post is deleted" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      %{post: post, ascent: ascent} =
        ascent_post_fixture(scope: scope, gym: gym, problem: problem, body: "")

      assert {:ok, deleted_post} = Feed.delete_post(scope, gym, post)
      assert deleted_post.deleted_at
      assert Repo.get!(Ascent, ascent.id).deleted_at
    end
  end

  describe "get_user_stats/3" do
    test "returns owner-only ascent aggregates" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      other_scope = user_scope_fixture()
      bloc_house = gym_fixture(name: "Bloc House")
      slab_lab = gym_fixture(name: "Slab Lab")
      bloc_v3 = boulder_problem_fixture(gym: bloc_house, grade: "V3", title: "Blue Rail")
      bloc_v5 = boulder_problem_fixture(gym: bloc_house, grade: "V5", title: "Pink Press")
      slab_v3 = boulder_problem_fixture(gym: slab_lab, grade: "V3", title: "Quiet Feet")
      {:ok, _membership} = Gyms.join_gym(scope, bloc_house)
      {:ok, _membership} = Gyms.join_gym(scope, slab_lab)

      ascent_post_fixture(
        scope: scope,
        gym: bloc_house,
        problem: bloc_v3,
        climbed_at: "2026-06-12T10:30"
      )

      ascent_post_fixture(
        scope: scope,
        gym: bloc_house,
        problem: bloc_v5,
        climbed_at: "2026-06-05T10:30"
      )

      %{post: deleted_post} =
        ascent_post_fixture(
          scope: scope,
          gym: bloc_house,
          problem: bloc_v5,
          climbed_at: "2026-05-28T10:30"
        )

      ascent_post_fixture(
        scope: scope,
        gym: slab_lab,
        problem: slab_v3,
        climbed_at: "2026-05-23T10:30"
      )

      ascent_post_fixture(
        scope: other_scope,
        gym: bloc_house,
        problem: bloc_v3,
        climbed_at: "2026-06-12T10:30"
      )

      assert {:ok, _post} = Feed.delete_post(scope, bloc_house, deleted_post)

      assert {:ok, stats} = AscentLogs.get_user_stats(scope, user, today: ~D[2026-06-13])

      assert stats.total_ascents == 3
      assert stats.unique_gyms == 2
      assert stats.unique_routes == 3

      assert stats.grade_distribution == [
               %{grade: "V3", count: 2},
               %{grade: "V5", count: 1}
             ]

      assert stats.gym_distribution == [
               %{gym_id: bloc_house.id, gym_name: "Bloc House", count: 2},
               %{gym_id: slab_lab.id, gym_name: "Slab Lab", count: 1}
             ]

      timeline_counts = Map.new(stats.timeline, &{&1.week_start, &1.count})

      assert length(stats.timeline) == 12
      assert timeline_counts[~D[2026-06-08]] == 1
      assert timeline_counts[~D[2026-06-01]] == 1
      assert timeline_counts[~D[2026-05-18]] == 1
      assert timeline_counts[~D[2026-05-25]] == 0
    end

    test "rejects stats access for other users" do
      owner = user_fixture()
      viewer_scope = user_scope_fixture()

      assert AscentLogs.get_user_stats(viewer_scope, owner) == {:error, :unauthorized}
    end
  end
end
