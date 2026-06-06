defmodule AscentsWeb.GymLiveTest do
  use AscentsWeb.ConnCase, async: true

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Gyms

  describe "index" do
    test "renders public gym index", %{conn: conn} do
      gym = gym_fixture(name: "Bloc District")

      {:ok, view, _html} = live(conn, ~p"/gyms")

      assert has_element?(view, "#gyms-index")
      assert has_element?(view, "#gym-card-#{gym.id}")
      refute has_element?(view, "a[href='/gyms/new']")
    end

    test "shows create link for authenticated users", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} = live(conn, ~p"/gyms")

      assert has_element?(view, "#gyms-index")
      assert has_element?(view, "a[href='/gyms/new']")
    end
  end

  describe "new" do
    test "redirects anonymous users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/gyms/new")
    end

    test "creates a gym and navigates to generated slug", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/new")

      view
      |> form("#gym-new-form",
        gym: %{
          name: "Summit House",
          location: "Madrid",
          grade_scale: "french",
          description: "Steep boards and quiet slab mornings."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/gyms/summit-house")

      gym = Gyms.get_gym_by_slug("summit-house")
      assert gym.name == "Summit House"
      assert Gyms.get_membership(user, gym).role == "owner"
    end

    test "validates the create form", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} = live(conn, ~p"/gyms/new")

      assert view
             |> form("#gym-new-form", gym: %{name: "A", grade_scale: "v_scale"})
             |> render_change() =~ "should be at least 2 character(s)"
    end
  end

  describe "show" do
    test "renders public gym page without membership controls", %{conn: conn} do
      gym = gym_fixture(name: "North Cave")

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-show")
      assert has_element?(view, "#gym-description")
      refute has_element?(view, "#gym-join-button")
      refute has_element?(view, "#gym-leave-button")
      refute has_element?(view, "#gym-settings-link")
    end

    test "allows authenticated non-members to join", %{conn: conn} do
      gym = gym_fixture()
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-join-button")

      view
      |> element("#gym-join-button")
      |> render_click()

      assert has_element?(view, "#gym-leave-button")
      assert Gyms.get_membership(user, gym).role == "member"
    end

    test "allows members to leave", %{conn: conn} do
      gym = gym_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-leave-button")

      view
      |> element("#gym-leave-button")
      |> render_click()

      assert has_element?(view, "#gym-join-button")
      refute Gyms.get_membership(user, gym)
    end

    test "prevents the only owner from leaving", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view
      |> element("#gym-leave-button")
      |> render_click()

      assert has_element?(view, "#gym-leave-button")
      assert Gyms.get_membership(owner, gym).role == "owner"
    end

    test "shows management links for owners", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-settings-link")
      assert has_element?(view, "#gym-members-link")
    end
  end

  describe "settings" do
    test "redirects anonymous users", %{conn: conn} do
      gym = gym_fixture()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/gyms/#{gym.slug}/settings")
    end

    test "redirects non-admin members", %{conn: conn} do
      gym = gym_fixture()
      member = user_fixture()
      member_scope = user_scope_fixture(member)
      role_membership_fixture(gym, "member", scope: member_scope)
      conn = log_in_user(conn, member)
      gym_path = ~p"/gyms/#{gym.slug}"

      assert {:error, {:live_redirect, %{to: ^gym_path}}} =
               live(conn, ~p"/gyms/#{gym.slug}/settings")
    end

    test "allows owners to update settings without editing slug", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope, name: "Old Name")
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/settings")

      assert has_element?(view, "#gym-settings-form")

      view
      |> form("#gym-settings-form",
        gym: %{
          name: "New Name",
          location: "Lisbon",
          grade_scale: "french",
          description: "Updated wall notes."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/gyms/#{gym.slug}")

      updated_gym = Gyms.get_gym!(gym.id)
      assert updated_gym.name == "New Name"
      assert updated_gym.slug == gym.slug
      assert updated_gym.location == "Lisbon"
      assert updated_gym.grade_scale == "french"
    end
  end

  describe "members" do
    test "redirects anonymous users", %{conn: conn} do
      gym = gym_fixture()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/gyms/#{gym.slug}/members")
    end

    test "redirects non-admin members", %{conn: conn} do
      gym = gym_fixture()
      member = user_fixture()
      member_scope = user_scope_fixture(member)
      role_membership_fixture(gym, "member", scope: member_scope)
      conn = log_in_user(conn, member)
      gym_path = ~p"/gyms/#{gym.slug}"

      assert {:error, {:live_redirect, %{to: ^gym_path}}} =
               live(conn, ~p"/gyms/#{gym.slug}/members")
    end

    test "renders members for owners", %{conn: conn} do
      owner = user_fixture(username: "owner_user")
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)

      role_membership_fixture(
        gym,
        "member",
        scope: user_scope_fixture(user_fixture(username: "member_user"))
      )

      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/members")

      assert has_element?(view, "#gym-members-table")
      assert has_element?(view, "#gym-membership-#{Gyms.get_membership(owner, gym).id}")
      assert render(view) =~ "member_user"
    end

    test "updates member roles", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      membership = role_membership_fixture(gym, "member")
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/members")

      view
      |> form("#membership-role-form-#{membership.id}",
        membership_id: membership.id,
        role: "mod"
      )
      |> render_change()

      assert {:ok, memberships} = Gyms.list_gym_memberships(scope, gym)
      assert Enum.find(memberships, &(&1.id == membership.id)).role == "mod"
    end

    test "removes non-owner members", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      membership = role_membership_fixture(gym, "member")
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/members")

      view
      |> element("#membership-remove-button-#{membership.id}")
      |> render_click()

      refute has_element?(view, "#gym-membership-#{membership.id}")
    end

    test "does not remove owner memberships", %{conn: conn} do
      owner = user_fixture()
      scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: scope)
      owner_membership = Gyms.get_membership(owner, gym)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/members")

      assert has_element?(view, "#membership-remove-button-#{owner_membership.id}[disabled]")
      assert Gyms.get_membership(owner, gym).role == "owner"
    end
  end
end
