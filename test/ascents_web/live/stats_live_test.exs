defmodule AscentsWeb.StatsLiveTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.AscentsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Phoenix.LiveViewTest

  describe "show" do
    test "redirects anonymous users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/users/stats")
    end

    test "renders empty stats for the logged-in user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/stats")

      assert has_element?(view, "#user-stats-show")
      assert has_element?(view, "#user-stats-summary")
      assert has_element?(view, "#user-stats-empty")
      refute has_element?(view, "#user-stats-timeline-chart")
    end

    test "renders chart surfaces for a user with seeded ascents", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(name: "Bloc House")
      problem = boulder_problem_fixture(gym: gym, grade: "V3")

      ascent_post_fixture(
        scope: scope,
        gym: gym,
        problem: problem,
        climbed_at: "2026-06-12T10:30"
      )

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/stats")

      assert has_element?(view, "#user-stats-show")
      assert has_element?(view, "#user-stats-timeline-chart[phx-hook='StatsChart']")
      assert has_element?(view, "#user-stats-gym-chart[phx-hook='StatsChart']")
      assert has_element?(view, "#user-stats-grade-chart[phx-hook='StatsChart']")
      assert has_element?(view, "#user-stats-grade-list [data-component='grade-badge']")
      refute has_element?(view, "#user-stats-empty")
    end
  end
end
