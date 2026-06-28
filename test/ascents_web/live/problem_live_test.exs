defmodule AscentsWeb.ProblemLiveTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Media.TestStorage

  setup do
    TestStorage.reset!()
    :ok
  end

  describe "gym route visibility" do
    test "renders active routes on the public gym page", %{conn: conn} do
      gym = gym_fixture(name: "Route Room")
      problem = boulder_problem_fixture(gym: gym, title: "Blue Groove", grade: "V2")
      archived_problem = boulder_problem_fixture(gym: gym, title: "Old Slab", grade: "V1")
      admin_scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: admin_scope)

      {:ok, _archived} =
        ClimbingRoutes.archive_boulder_problem(admin_scope, gym, archived_problem)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-content-grid > #gym-active-routes")
      assert has_element?(view, "#gym-content-grid > #gym-feed")
      assert has_element?(view, "#gym-active-routes.order-1")
      assert has_element?(view, "#gym-active-route-list.grid")
      assert has_element?(view, "#gym-route-card-#{problem.id}")
      refute has_element?(view, "#gym-route-card-#{problem.id} .route-status-badge")
      refute has_element?(view, "#gym-route-card-#{archived_problem.id}")
      refute has_element?(view, "#gym-routes-link")
    end

    test "shows route management links to admins", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-routes-link")
      assert has_element?(view, "#gym-new-route-link")
    end
  end

  describe "index" do
    test "redirects anonymous users", %{conn: conn} do
      gym = gym_fixture()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/gyms/#{gym.slug}/problems")
    end

    test "redirects non-admin members", %{conn: conn} do
      gym = gym_fixture()
      member = user_fixture()
      member_scope = user_scope_fixture(member)
      role_membership_fixture(gym, "member", scope: member_scope)
      conn = log_in_user(conn, member)
      gym_path = ~p"/gyms/#{gym.slug}"

      assert {:error, {:live_redirect, %{to: ^gym_path}}} =
               live(conn, ~p"/gyms/#{gym.slug}/problems")
    end

    test "renders active and archived problems for admins", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      active_problem = boulder_problem_fixture(gym: gym, scope: scope, title: "New Arete")
      archived_problem = boulder_problem_fixture(gym: gym, scope: scope, title: "Old Arete")
      {:ok, _archived} = ClimbingRoutes.archive_boulder_problem(scope, gym, archived_problem)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems")

      assert has_element?(view, "#problem-admin-index")
      assert has_element?(view, "#problem-admin-card-#{active_problem.id}")
      assert has_element?(view, "#problem-admin-card-#{archived_problem.id}")
      assert has_element?(view, "#problem-archive-button-#{active_problem.id}")
      assert has_element?(view, "#problem-reactivate-button-#{archived_problem.id}")
    end

    test "archives and reactivates problems", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      problem = boulder_problem_fixture(gym: gym, scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems")

      view
      |> element("#problem-archive-button-#{problem.id}")
      |> render_click()

      assert has_element?(view, "#problem-reactivate-button-#{problem.id}")
      refute ClimbingRoutes.get_boulder_problem!(gym, problem.id).active

      view
      |> element("#problem-reactivate-button-#{problem.id}")
      |> render_click()

      assert has_element?(view, "#problem-archive-button-#{problem.id}")
      assert ClimbingRoutes.get_boulder_problem!(gym, problem.id).active
    end
  end

  describe "new" do
    test "offers image picking with MIME hints and extension fallback", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems/new")

      assert has_element?(
               view,
               "#route-new-image-upload input[type='file'][name='image'][accept*='.jpg,.jpeg,.png,.webp']"
             )

      assert has_element?(
               view,
               "#route-new-image-upload input[accept*='image/jpeg'][accept*='image/png'][accept*='image/webp']"
             )

      refute has_element?(
               view,
               "#route-new-image-upload input[capture]"
             )
    end

    test "creates a boulder problem", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems/new")

      view
      |> form("#problem-new-form",
        boulder_problem: %{
          title: "Pinch Rail",
          grade: "V4",
          color: "Green",
          description: "Hard first move."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/gyms/#{gym.slug}/problems")

      assert [problem] = ClimbingRoutes.list_boulder_problems(gym)
      assert problem.title == "Pinch Rail"
      assert problem.image_object_key == nil
    end

    test "uploads a boulder problem image", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems/new")

      upload =
        file_input(view, "#problem-new-form", :image, [
          %{name: "pinch-rail.jpg", content: "route image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "pinch-rail.jpg") =~ "100%"

      view
      |> form("#problem-new-form",
        boulder_problem: %{
          title: "Pinch Rail",
          grade: "V4",
          color: "Green",
          description: "Hard first move."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/gyms/#{gym.slug}/problems")

      assert [problem] = ClimbingRoutes.list_boulder_problems(gym)
      assert problem.image_object_key =~ ~r/^problems\/pending\//
    end

    test "validates the route form", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope, grade_scale: "french")
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems/new")

      assert view
             |> form("#problem-new-form",
               boulder_problem: %{title: "A", grade: "6A", color: "B"}
             )
             |> render_change() =~ "should be at least 2 character(s)"
    end
  end

  describe "edit" do
    test "offers image picking with MIME hints and extension fallback", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      problem = boulder_problem_fixture(gym: gym, scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems/#{problem.id}/edit")

      assert has_element?(
               view,
               "#route-edit-image-upload input[type='file'][name='image'][accept*='.jpg,.jpeg,.png,.webp']"
             )

      assert has_element?(
               view,
               "#route-edit-image-upload input[accept*='image/jpeg'][accept*='image/png'][accept*='image/webp']"
             )

      refute has_element?(
               view,
               "#route-edit-image-upload input[capture]"
             )
    end

    test "updates a boulder problem", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      problem = boulder_problem_fixture(gym: gym, scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/problems/#{problem.id}/edit")

      view
      |> form("#problem-edit-form",
        boulder_problem: %{
          title: "Updated Pinch",
          grade: "V5",
          color: "Purple",
          description: "Fresh finish."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/gyms/#{gym.slug}/problems")
      assert ClimbingRoutes.get_boulder_problem!(gym, problem.id).title == "Updated Pinch"
    end
  end
end
