defmodule Ascents.AscentsTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.AscentsFixtures
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

      assert %Ascent{} = ascent
      assert ascent.post_id == post.id
      assert ascent.gym_id == gym.id
      assert ascent.user_id == user.id
      assert ascent.boulder_problem_id == problem.id
      assert ascent.grade_snapshot == "6A"
      assert ascent.grade_scale_snapshot == "french"
      assert ascent.climbed_at == ~U[2026-06-11 10:30:00Z]
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
end
