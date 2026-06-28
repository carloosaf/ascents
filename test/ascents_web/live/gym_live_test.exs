defmodule AscentsWeb.GymLiveTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Ascents, as: AscentLogs
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed
  alias Ascents.Gyms
  alias Ascents.Media.TestStorage
  alias Ascents.Repo
  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Sessions.Session

  setup do
    TestStorage.reset!()
    :ok
  end

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
      assert gym.image_object_key == nil
      assert Gyms.get_membership(user, gym).role == "owner"
    end

    test "uploads a gym image", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/new")

      upload =
        file_input(view, "#gym-new-form", :image, [
          %{name: "wall.jpg", content: "gym image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "wall.jpg") =~ "100%"

      view
      |> form("#gym-new-form",
        gym: %{
          name: "Upload Wall",
          location: "Madrid",
          grade_scale: "v_scale",
          description: "Fresh paint."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/gyms/upload-wall")

      gym = Gyms.get_gym_by_slug("upload-wall")
      assert gym.image_object_key =~ ~r/^gyms\/pending\//
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
      assert has_element?(view, "[data-component='gym-header'] #gym-description")
      assert has_element?(view, "#gym-verification-community-badge")
      refute has_element?(view, "#gym-join-button")
      refute has_element?(view, "#gym-leave-button")
      refute has_element?(view, "#gym-settings-link")
      refute has_element?(view, "#gym-verification-link")
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
      assert has_element?(view, "#gym-verification-link")
    end

    test "renders pending and verified ownership badges", %{conn: conn} do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      {:ok, pending_gym} =
        Gyms.request_verification(owner_scope, gym, %{
          note: "I operate this gym and can confirm through our official website."
        })

      {:ok, pending_view, _html} = live(conn, ~p"/gyms/#{pending_gym.slug}")
      assert has_element?(pending_view, "#gym-verification-pending-badge")

      platform_admin_scope =
        user_fixture(email: "platform-admin@example.com")
        |> user_scope_fixture()

      {:ok, verified_gym} =
        Gyms.approve_verification(platform_admin_scope, pending_gym, %{
          note: "Verified through the gym's published business contact."
        })

      {:ok, verified_view, _html} = live(conn, ~p"/gyms/#{verified_gym.slug}")
      assert has_element?(verified_view, "#gym-verification-verified-badge")
      assert has_element?(verified_view, "#gym-verification-note")
    end

    test "renders gym feed posts on the gym root", %{conn: conn} do
      gym = gym_fixture(name: "Feed Wall")
      post = post_fixture(gym: gym, body: "Evening session notes.")

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-feed")
      assert has_element?(view, "#posts-#{post.id}")
      refute has_element?(view, "#gym-post-form")
    end

    test "filters friends-only gym posts for every viewer role", %{conn: conn} do
      author = user_fixture()
      friend = user_fixture()
      non_friend = user_fixture()
      moderator = user_fixture()
      author_scope = user_scope_fixture(author)
      gym = gym_fixture()
      role_membership_fixture(gym, "mod", scope: user_scope_fixture(moderator))
      accepted_friendship_fixture(requester: author, recipient: friend)

      post =
        post_fixture(scope: author_scope, gym: gym, body: "Private beta", visibility: "friends")

      {:ok, anonymous_view, _html} = live(conn, ~p"/gyms/#{gym.slug}")
      refute has_element?(anonymous_view, "#posts-#{post.id}")

      for viewer <- [author, friend] do
        {:ok, view, _html} = live(log_in_user(build_conn(), viewer), ~p"/gyms/#{gym.slug}")
        assert has_element?(view, "#posts-#{post.id}")
      end

      for viewer <- [non_friend, moderator] do
        {:ok, view, _html} = live(log_in_user(build_conn(), viewer), ~p"/gyms/#{gym.slug}")
        refute has_element?(view, "#posts-#{post.id}")
      end
    end

    test "allows members to create posts", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#gym-feed-posts > #gym-feed-empty[class~='hidden']")
      assert has_element?(view, "#gym-feed-posts > #gym-feed-empty[class~='only:block']")

      view
      |> element("#gym-new-post-button")
      |> render_click()

      assert has_element?(view, "#gym-post-modal")
      assert has_element?(view, "#app-sidebar[class~='z-40']")
      assert has_element?(view, "#app-mobile-tabbar[class~='z-40']")
      assert has_element?(view, "#app-shell > #gym-post-modal.ascents-modal-overlay")
      refute has_element?(view, "main #gym-post-modal")
      assert has_element?(view, "#gym-post-visibility option[selected][value='public']")

      view
      |> form("#gym-post-form",
        post: %{body: "New slab is technical.", visibility: "friends"}
      )
      |> render_submit()

      assert [post] = Feed.list_gym_posts(scope, gym)
      assert post.body == "New slab is technical."
      assert post.visibility == "friends"
      assert post.gym_id == gym.id
      assert has_element?(view, "#posts-#{post.id}")
      assert has_element?(view, "#gym-feed-posts > #gym-feed-empty[class~='hidden']")
      assert has_element?(view, "#gym-feed-posts > #gym-feed-empty[class~='only:block']")
    end

    test "allows post images", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view
      |> element("#gym-new-post-button")
      |> render_click()

      upload =
        file_input(view, "#gym-post-form", :image, [
          %{name: "send.jpg", content: "post image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "send.jpg") =~ "100%"

      view
      |> form("#gym-post-form", post: %{body: "Photo beta."})
      |> render_submit()

      assert [post] = Feed.list_gym_posts(scope, gym)
      assert post.image_object_key =~ ~r/^posts\/pending\//
    end

    test "allows members to create ascent posts without notes", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view
      |> element("#gym-new-post-button")
      |> render_click()

      view
      |> element("#gym-post-ascent-mode")
      |> render_click()

      assert has_element?(view, "#gym-ascent-post-form")

      assert has_element?(
               view,
               "#gym-ascent-post-visibility option[selected][value='public']"
             )

      assert has_element?(view, "#gym-ascent-post-visibility option[value='private']")

      view
      |> form("#gym-ascent-post-form",
        ascent_post: %{
          boulder_problem_id: problem.id,
          climbed_at: "2026-06-11T10:30",
          body: "",
          visibility: "private"
        }
      )
      |> render_submit()

      assert [post] = Feed.list_gym_posts(scope, gym)
      assert Feed.list_gym_posts(gym) == []
      assert post.post_type == "ascent"
      assert post.body == nil
      assert post.boulder_problem_id == problem.id
      assert post.visibility == "private"
      assert post.gym_id == gym.id
      assert has_element?(view, "#home-post-ascent-#{post.id}")
      assert has_element?(view, "#home-post-privacy-#{post.id}", "Private")

      ascent = AscentLogs.get_ascent_by_post(scope, post)
      assert ascent.grade_snapshot == problem.grade
      assert ascent.climbed_at == ~U[2026-06-11 10:30:00Z]
    end

    test "shows validation when ascent route is missing", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view
      |> element("#gym-new-post-button")
      |> render_click()

      view
      |> element("#gym-post-ascent-mode")
      |> render_click()

      html =
        view
        |> form("#gym-ascent-post-form",
          ascent_post: %{boulder_problem_id: "", climbed_at: "2026-06-11T10:30", body: ""}
        )
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Feed.list_gym_posts(scope, gym) == []
      assert has_element?(view, "#gym-ascent-post-form")
    end

    test "renders existing ascent posts in the gym feed", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      problem = boulder_problem_fixture(gym: gym, title: "Moonboard Pinch")
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      {:ok, %{post: post}} =
        AscentLogs.create_ascent_post(scope, gym, %{
          boulder_problem_id: problem.id,
          climbed_at: "2026-06-11T10:30",
          body: "Finally linked the finish."
        })

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#posts-#{post.id}")
      assert has_element?(view, "#home-post-ascent-#{post.id}")
    end

    test "switches between post, ascent, and session composer modes", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      assert has_element?(view, "#gym-post-form")

      view |> element("#gym-post-session-mode") |> render_click()
      assert has_element?(view, "#gym-session-form")
      refute has_element?(view, "#gym-post-form")

      view |> element("#gym-post-ascent-mode") |> render_click()
      assert has_element?(view, "#gym-ascent-post-form")
      refute has_element?(view, "#gym-session-form")
    end

    test "rejects forged session composer events from non-members", %{conn: conn} do
      user = user_fixture()
      gym = gym_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      render_hook(view, "select-post-mode", %{"mode" => "session"})

      refute has_element?(view, "#gym-session-form")
      assert has_element?(view, "#flash-error")
    end

    test "closes the session composer when membership is revoked before row mutation", %{
      conn: conn
    } do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(scope: owner_scope)
      boulder_problem_fixture(gym: gym)
      {:ok, membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      assert has_element?(view, "#gym-session-form")

      assert {:ok, _membership} = Gyms.remove_membership(owner_scope, gym, membership.id)

      view |> element("#gym-session-add-ascent") |> render_click()

      refute has_element?(view, "#gym-post-modal")
      refute has_element?(view, "#session-ascent-row-2")
      assert has_element?(view, "#gym-join-button")
      assert has_element?(view, "#flash-error")
    end

    test "denies revoked members before consuming a session upload", %{conn: conn} do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(scope: owner_scope)
      problem = boulder_problem_fixture(gym: gym)
      {:ok, membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      upload =
        file_input(view, "#gym-session-form", :image, [
          %{name: "revoked.jpg", content: "session image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "revoked.jpg") =~ "100%"

      assert {:ok, _membership} = Gyms.remove_membership(owner_scope, gym, membership.id)

      view
      |> form("#gym-session-form",
        session: %{
          started_at: "2026-06-24T18:30",
          notes: "This should not persist.",
          visibility: "public",
          ascents: %{"1" => %{boulder_problem_id: problem.id}}
        }
      )
      |> render_submit()

      assert Feed.list_gym_posts(scope, gym) == []
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
      assert TestStorage.objects() == %{}
      refute has_element?(view, "#gym-post-modal")
      assert has_element?(view, "#gym-join-button")
      assert has_element?(view, "#flash-error")
    end

    test "adds and removes session ascent rows without changing stable row IDs", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      assert has_element?(view, "#session-ascent-row-1[data-row-id='1']")
      refute has_element?(view, "#session-ascent-row-2")

      view |> element("#gym-session-add-ascent") |> render_click()

      assert has_element?(view, "#session-ascent-row-1[data-row-id='1']")
      assert has_element?(view, "#session-ascent-row-2[data-row-id='2']")

      view |> element("#gym-session-remove-ascent-1") |> render_click()

      refute has_element?(view, "#session-ascent-row-1")
      assert has_element?(view, "#session-ascent-row-2[data-row-id='2']")

      view |> element("#gym-session-add-ascent") |> render_click()

      assert has_element?(view, "#session-ascent-row-2[data-row-id='2']")
      assert has_element?(view, "#session-ascent-row-3[data-row-id='3']")
    end

    test "ignores malformed session row payloads and keeps row IDs stable", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()
      view |> element("#gym-session-add-ascent") |> render_click()

      for params <- [
            %{},
            %{"row-id" => 1},
            %{"row-id" => "not-a-row"},
            %{"row-id" => "999"}
          ] do
        render_hook(view, "remove-session-ascent", params)

        assert has_element?(view, "#session-ascent-row-1[data-row-id='1']")
        assert has_element?(view, "#session-ascent-row-2[data-row-id='2']")
      end

      for ascents <- [
            123,
            %{"1" => 123, "2" => "not-a-map", "999" => %{boulder_problem_id: "999"}}
          ] do
        render_hook(view, "validate-session", %{
          "session" => %{
            "started_at" => "2026-06-24T18:30",
            "visibility" => "public",
            "ascents" => ascents
          }
        })

        assert has_element?(view, "#session-ascent-row-1[data-row-id='1']")
        assert has_element?(view, "#session-ascent-row-2[data-row-id='2']")
      end
    end

    test "does not render a session title field and keeps route errors scoped", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      boulder_problem_fixture(gym: gym)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      refute has_element?(view, "#gym-session-title")
      refute has_element?(view, "#gym-session-title-field")
      assert has_element?(view, "#gym-session-ascent-rows.max-h-80.overflow-y-auto")

      view
      |> form("#gym-session-form",
        session: %{
          started_at: "2026-06-24T18:30",
          notes: "Warming up before picking routes.",
          visibility: "public",
          ascents: %{"1" => %{boulder_problem_id: ""}}
        }
      )
      |> render_change()

      refute has_element?(view, "#gym-session-route-field-1 p")
      refute has_element?(view, "#gym-session-ascents-error")

      render_hook(view, "validate-session", %{
        "_target" => ["session", "ascents", "1", "boulder_problem_id"],
        "session" => %{
          "started_at" => "2026-06-24T18:30",
          "notes" => "Now the route selector has been touched.",
          "visibility" => "public",
          "ascents" => %{"1" => %{"boulder_problem_id" => ""}}
        }
      })

      assert has_element?(view, "#gym-session-route-field-1 p")
      assert has_element?(view, "#gym-session-ascents-error")
    end

    test "validates session metadata and route rows", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      upload =
        file_input(view, "#gym-session-form", :image, [
          %{name: "invalid-session.jpg", content: "session image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "invalid-session.jpg") =~ "100%"

      view
      |> form("#gym-session-form",
        session: %{
          started_at: "2026-06-24T18:30",
          notes: "",
          visibility: "public",
          ascents: %{"1" => %{boulder_problem_id: ""}}
        }
      )
      |> render_submit()

      assert has_element?(view, "#gym-session-route-field-1 p")
      assert has_element?(view, "#gym-session-ascents-error")
      assert Feed.list_gym_posts(scope, gym) == []
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
      assert TestStorage.objects() == %{}
    end

    test "ignores forged session image keys when session submit fails", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      referenced_key = "posts/referenced-session-media.jpg"
      :ok = TestStorage.put_object(referenced_key, "existing image", "image/jpeg", [])
      referenced_post = post_fixture(scope: scope, gym: gym, image_object_key: referenced_key)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      html =
        render_submit(view, "create-session", %{
          "session" => %{
            "started_at" => "2026-06-24T18:30",
            "notes" => "",
            "visibility" => "public",
            "image_object_key" => referenced_key,
            "ascents" => %{"1" => %{"boulder_problem_id" => ""}}
          }
        })

      assert has_element?(view, "#gym-session-route-field-1 p")
      assert has_element?(view, "#gym-session-ascents-error")
      refute html =~ referenced_key
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
      assert Map.fetch!(TestStorage.objects(), referenced_key) == {"existing image", "image/jpeg"}

      referenced_post_id = referenced_post.id

      assert [%{id: ^referenced_post_id, image_object_key: ^referenced_key}] =
               Feed.list_gym_posts(scope, gym)
    end

    test "removes uploaded session image when a route is archived after composer opens", %{
      conn: conn
    } do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(scope: owner_scope)
      problem = boulder_problem_fixture(gym: gym, scope: owner_scope)
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()

      upload =
        file_input(view, "#gym-session-form", :image, [
          %{name: "archived-route.jpg", content: "session image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "archived-route.jpg") =~ "100%"
      assert {:ok, _problem} = ClimbingRoutes.archive_boulder_problem(owner_scope, gym, problem)

      view
      |> form("#gym-session-form",
        session: %{
          started_at: "2026-06-24T18:30",
          notes: "",
          visibility: "public",
          ascents: %{"1" => %{boulder_problem_id: problem.id}}
        }
      )
      |> render_submit()

      assert has_element?(view, "#gym-session-ascents-error")
      assert Feed.list_gym_posts(scope, gym) == []
      assert Repo.aggregate(Session, :count) == 0
      assert Repo.aggregate(Ascent, :count) == 0
      assert TestStorage.objects() == %{}
    end

    test "creates one grouped feed card and two stats ascents with private media", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      first_problem = boulder_problem_fixture(gym: gym, title: "Blue Arete", grade: "V3")
      second_problem = boulder_problem_fixture(gym: gym, title: "Roof Pinch", grade: "V5")
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view |> element("#gym-new-post-button") |> render_click()
      view |> element("#gym-post-session-mode") |> render_click()
      view |> element("#gym-session-add-ascent") |> render_click()

      upload =
        file_input(view, "#gym-session-form", :image, [
          %{name: "training.jpg", content: "session image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "training.jpg") =~ "100%"

      view
      |> form("#gym-session-form",
        session: %{
          started_at: "2026-06-24T18:30",
          notes: "Linked both projects.",
          visibility: "friends",
          ascents: %{
            "1" => %{boulder_problem_id: first_problem.id},
            "2" => %{boulder_problem_id: second_problem.id}
          }
        }
      )
      |> render_submit()

      assert [post] = Feed.list_gym_posts(scope, gym)
      assert post.post_type == "session"
      assert post.visibility == "friends"
      assert post.image_object_key =~ ~r/^posts\/pending\//
      assert length(post.session.ascents) == 2

      assert has_element?(view, "#posts-#{post.id}")
      assert has_element?(view, "#home-post-session-#{post.id}")
      refute has_element?(view, "#home-post-session-title-#{post.id}")
      assert has_element?(view, "#home-post-privacy-#{post.id}", "Friends")
      assert has_element?(view, "#home-post-image-#{post.id}[src*='/media/']")

      for ascent <- post.session.ascents do
        assert has_element?(view, "#home-post-session-route-#{ascent.id}")
      end

      assert {:ok, stats} = AscentLogs.get_user_stats(scope, user)
      assert stats.total_ascents == 2
    end

    test "allows members to comment and content owners to delete comments", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      post = post_fixture(gym: gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view
      |> form("#home-comment-form-#{post.id}", post_id: post.id, comment: %{body: "Looks good."})
      |> render_submit()

      reloaded_post = Feed.get_post(scope, gym, post.id)
      assert [comment] = reloaded_post.comments
      assert has_element?(view, "#home-comment-#{comment.id}")

      view
      |> element("#home-comment-delete-#{comment.id}")
      |> render_click()

      assert Ascents.Repo.get!(Ascents.Feed.Comment, comment.id).deleted_at
      assert Feed.get_post(scope, gym, post.id).comments == []
      refute has_element?(view, "#home-comment-#{comment.id}")
    end

    test "allows content owners to delete posts", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      {:ok, post} = Feed.create_post(scope, gym, %{body: "Delete me"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      view
      |> element("#home-post-delete-#{post.id}")
      |> render_click()

      assert Feed.list_gym_posts(scope, gym) == []
      refute has_element?(view, "#posts-#{post.id}")
    end

    test "allows gym admins to delete member posts and comments", %{conn: conn} do
      gym = gym_fixture()
      post = post_fixture(gym: gym)
      comment = comment_fixture(post: post, gym: gym)
      admin = user_fixture()
      admin_scope = user_scope_fixture(admin)
      role_membership_fixture(gym, "admin", scope: admin_scope)
      conn = log_in_user(conn, admin)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      assert has_element?(view, "#home-post-delete-#{post.id}")
      assert has_element?(view, "#home-comment-delete-#{comment.id}")

      view
      |> element("#home-comment-delete-#{comment.id}")
      |> render_click()

      refute has_element?(view, "#home-comment-#{comment.id}")

      view
      |> element("#home-post-delete-#{post.id}")
      |> render_click()

      assert Feed.list_gym_posts(admin_scope, gym) == []
      refute has_element?(view, "#posts-#{post.id}")
    end

    test "hides moderation controls from regular non-author members", %{conn: conn} do
      gym = gym_fixture()
      post = post_fixture(gym: gym)
      comment = comment_fixture(post: post, gym: gym)
      member = user_fixture()
      member_scope = user_scope_fixture(member)
      {:ok, _membership} = Gyms.join_gym(member_scope, gym)
      conn = log_in_user(conn, member)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}")

      refute has_element?(view, "#home-post-delete-#{post.id}")
      refute has_element?(view, "#home-comment-delete-#{comment.id}")
    end
  end

  describe "verification" do
    setup do
      previous_platform_admin_emails =
        Application.get_env(:ascents, :platform_admin_emails, :not_configured)

      Application.put_env(:ascents, :platform_admin_emails, ["platform-admin@example.com"])

      on_exit(fn ->
        case previous_platform_admin_emails do
          :not_configured ->
            Application.delete_env(:ascents, :platform_admin_emails)

          emails ->
            Application.put_env(:ascents, :platform_admin_emails, emails)
        end
      end)
    end

    test "redirects anonymous users before the LiveView mounts", %{conn: conn} do
      gym = gym_fixture()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/gyms/#{gym.slug}/verification")
    end

    test "redirects authenticated users without gym admin or platform privileges", %{conn: conn} do
      gym = gym_fixture()
      conn = log_in_user(conn, user_fixture())
      gym_path = ~p"/gyms/#{gym.slug}"

      assert {:error, {:live_redirect, %{to: ^gym_path}}} =
               live(conn, ~p"/gyms/#{gym.slug}/verification")
    end

    test "gym owners can submit a verification request", %{conn: conn} do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      conn = log_in_user(conn, owner)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{gym.slug}/verification")

      assert has_element?(view, "#gym-verification-request-form")

      view
      |> form("#gym-verification-request-form",
        verification_request: %{verification_request_note: "Too short"}
      )
      |> render_submit()

      assert has_element?(
               view,
               "#verification_request_verification_request_note.border-ascents-danger"
             )

      assert Gyms.get_gym!(gym.id).verification_status == "community"

      view
      |> form("#gym-verification-request-form",
        verification_request: %{
          verification_request_note:
            "I operate this gym and can confirm through our official website."
        }
      )
      |> render_submit()

      assert has_element?(view, "#gym-verification-pending-details")
      refute has_element?(view, "#gym-verification-request-form")

      pending_gym = Gyms.get_gym!(gym.id)
      assert pending_gym.verification_status == "pending"
      assert pending_gym.verification_requested_by_user_id == owner.id
    end

    test "gym-local admins cannot invoke the privileged approval event", %{conn: conn} do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      {:ok, pending_gym} =
        Gyms.request_verification(owner_scope, gym, %{
          note: "I operate this gym and can confirm through our official website."
        })

      local_admin = user_fixture()
      local_admin_scope = user_scope_fixture(local_admin)
      role_membership_fixture(gym, "admin", scope: local_admin_scope)
      conn = log_in_user(conn, local_admin)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{pending_gym.slug}/verification")

      refute has_element?(view, "#gym-verification-approval-form")

      render_hook(view, "approve-verification", %{
        "verification_approval" => %{
          "verification_note" => "Attempted approval by a gym-local admin."
        }
      })

      assert Gyms.get_gym!(gym.id).verification_status == "pending"
      refute has_element?(view, "#gym-verification-approved-details")
    end

    test "gym-local admins cannot forge the privileged revoke event", %{conn: conn} do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)
      platform_admin_scope = user_scope_fixture(user_fixture(email: "platform-admin@example.com"))

      {:ok, pending_gym} =
        Gyms.request_verification(owner_scope, gym, %{
          note: "I operate this gym and can confirm through our official website."
        })

      {:ok, verified_gym} =
        Gyms.approve_verification(platform_admin_scope, pending_gym, %{
          note: "Verified through the gym's published business contact."
        })

      local_admin = user_fixture()
      local_admin_scope = user_scope_fixture(local_admin)
      role_membership_fixture(gym, "admin", scope: local_admin_scope)
      conn = log_in_user(conn, local_admin)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{verified_gym.slug}/verification")

      refute has_element?(view, "#gym-verification-revoke-button")
      render_hook(view, "revoke-verification", %{})

      assert Gyms.get_gym!(gym.id).verification_status == "verified"
      assert has_element?(view, "#gym-verification-approved-details")
    end

    test "platform administrators can approve and revoke through server-authorized controls", %{
      conn: conn
    } do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      {:ok, pending_gym} =
        Gyms.request_verification(owner_scope, gym, %{
          note: "I operate this gym and can confirm through our official website."
        })

      platform_admin = user_fixture(email: "platform-admin@example.com")
      conn = log_in_user(conn, platform_admin)

      {:ok, view, _html} = live(conn, ~p"/gyms/#{pending_gym.slug}/verification")

      assert has_element?(view, "#gym-verification-approval-form")

      view
      |> form("#gym-verification-approval-form",
        verification_approval: %{
          verification_note: "Verified through the gym's published business contact."
        }
      )
      |> render_submit()

      assert has_element?(view, "#gym-verification-approved-details")
      assert has_element?(view, "#gym-verification-revoke-button")
      assert Gyms.get_gym!(gym.id).verification_status == "verified"

      view
      |> element("#gym-verification-revoke-button")
      |> render_click()

      assert has_element?(view, "#gym-verification-current-state")
      refute has_element?(view, "#gym-verification-approved-details")
      assert Gyms.get_gym!(gym.id).verification_status == "community"
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
