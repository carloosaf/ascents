defmodule Ascents.RoutesTest do
  use Ascents.DataCase

  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Routes.BoulderProblem

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures

  describe "change_boulder_problem/3" do
    test "returns a boulder problem changeset" do
      gym = gym_fixture()

      assert %Ecto.Changeset{} =
               changeset = ClimbingRoutes.change_boulder_problem(gym, %BoulderProblem{})

      assert changeset.required == [:gym_id, :title, :grade, :color, :active]
    end
  end

  describe "grade_options/1" do
    test "returns V scale options by default" do
      gym = gym_fixture(grade_scale: "v_scale")

      assert {"V0", "V0"} in ClimbingRoutes.grade_options(gym)
      assert {"V17", "V17"} in ClimbingRoutes.grade_options(gym)
    end

    test "returns French bouldering options" do
      gym = gym_fixture(grade_scale: "french")

      assert {"6A", "6A"} in ClimbingRoutes.grade_options(gym)
      assert {"8C+", "8C+"} in ClimbingRoutes.grade_options(gym)
    end
  end

  describe "create_boulder_problem/3" do
    test "requires route management access" do
      gym = gym_fixture()
      member_scope = user_scope_fixture()
      role_membership_fixture(gym, "member", scope: member_scope)

      assert ClimbingRoutes.create_boulder_problem(nil, gym, valid_boulder_problem_attributes()) ==
               {:error, :unauthorized}

      assert ClimbingRoutes.create_boulder_problem(
               member_scope,
               gym,
               valid_boulder_problem_attributes()
             ) == {:error, :unauthorized}
    end

    test "allows owners and admins to create boulder problems" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      assert {:ok, problem} =
               ClimbingRoutes.create_boulder_problem(
                 owner_scope,
                 gym,
                 valid_boulder_problem_attributes(
                   title: "Pocket Circuit",
                   grade: "v4",
                   image_object_key: "routes/pocket-circuit.jpg"
                 )
               )

      assert problem.gym_id == gym.id
      assert problem.title == "Pocket Circuit"
      assert problem.grade == "V4"
      assert problem.active
      assert problem.image_object_key == "routes/pocket-circuit.jpg"
    end

    test "validates grades against the gym scale" do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope, grade_scale: "french")

      assert {:error, changeset} =
               ClimbingRoutes.create_boulder_problem(
                 scope,
                 gym,
                 valid_boulder_problem_attributes(grade: "V4")
               )

      assert "is invalid" in errors_on(changeset).grade

      assert {:ok, problem} =
               ClimbingRoutes.create_boulder_problem(
                 scope,
                 gym,
                 valid_boulder_problem_attributes(grade: "6b+")
               )

      assert problem.grade == "6B+"
    end
  end

  describe "list_boulder_problems/2 and get_boulder_problem!/2" do
    test "scopes problems to the gym" do
      gym = gym_fixture(name: "One")
      other_gym = gym_fixture(name: "Two")
      problem = boulder_problem_fixture(gym: gym, title: "Scoped Route")
      _other_problem = boulder_problem_fixture(gym: other_gym, title: "Other Route")

      assert Enum.map(ClimbingRoutes.list_boulder_problems(gym), & &1.id) == [problem.id]
      assert ClimbingRoutes.get_boulder_problem!(gym, problem.id).id == problem.id

      assert_raise Ecto.NoResultsError, fn ->
        ClimbingRoutes.get_boulder_problem!(other_gym, problem.id)
      end
    end
  end

  describe "update_boulder_problem/4" do
    test "updates route metadata and keeps gym scope" do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      problem = boulder_problem_fixture(gym: gym, scope: scope)

      assert {:ok, updated_problem} =
               ClimbingRoutes.update_boulder_problem(scope, gym, problem, %{
                 title: "New Line",
                 grade: "V5",
                 color: "Pink",
                 description: "Updated notes.",
                 image_object_key: "routes/new-line.jpg"
               })

      assert updated_problem.title == "New Line"
      assert updated_problem.grade == "V5"
      assert updated_problem.color == "Pink"
      assert updated_problem.gym_id == gym.id
    end

    test "rejects non-admins and wrong gym scope" do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)
      other_gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym, scope: owner_scope)
      other_admin_scope = user_scope_fixture()
      role_membership_fixture(other_gym, "admin", scope: other_admin_scope)
      member_scope = user_scope_fixture()
      role_membership_fixture(gym, "member", scope: member_scope)

      assert ClimbingRoutes.update_boulder_problem(member_scope, gym, problem, %{title: "Nope"}) ==
               {:error, :unauthorized}

      assert ClimbingRoutes.update_boulder_problem(other_admin_scope, other_gym, problem, %{
               title: "Wrong Gym"
             }) == {:error, :not_found}
    end
  end

  describe "archive_boulder_problem/3 and reactivate_boulder_problem/3" do
    test "archives, hides from active lists, and reactivates" do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)
      problem = boulder_problem_fixture(gym: gym, scope: owner_scope)

      assert ClimbingRoutes.count_active_boulder_problems(gym) == 1

      assert {:ok, archived_problem} =
               ClimbingRoutes.archive_boulder_problem(owner_scope, gym, problem)

      refute archived_problem.active
      assert archived_problem.archived_at
      assert ClimbingRoutes.list_boulder_problems(gym) == []

      assert Enum.map(ClimbingRoutes.list_boulder_problems(gym, include_archived: true), & &1.id) ==
               [problem.id]

      assert {:ok, reactivated_problem} =
               ClimbingRoutes.reactivate_boulder_problem(owner_scope, gym, archived_problem)

      assert reactivated_problem.active
      refute reactivated_problem.archived_at
      assert ClimbingRoutes.count_active_boulder_problems(gym) == 1
    end
  end
end
