defmodule AscentsWeb.ProfileLiveTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Accounts
  alias Ascents.Accounts.Scope
  alias Ascents.Feed
  alias Ascents.Gyms
  alias Ascents.Media.TestStorage

  setup do
    TestStorage.reset!()
    :ok
  end

  describe "show" do
    test "redirects anonymous users", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/u/#{user.username}")
    end

    test "renders profile for logged-in users and hides email", %{conn: conn} do
      user = user_fixture()

      {:ok, user} =
        Accounts.update_user_profile(Scope.for_user(user), %{
          username: user.username,
          display_name: "Mara Silva",
          bio: "Technical slabs and quiet cave sessions."
        })

      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/u/#{user.username}")
      document = LazyHTML.from_fragment(html)

      assert document |> LazyHTML.query("#profile-show") |> Enum.any?()

      assert document |> LazyHTML.query("#profile-display-name") |> LazyHTML.text() =~
               "Mara Silva"

      assert LazyHTML.text(document) =~ "/u/#{user.username}"
      refute LazyHTML.text(document) =~ user.email
    end

    test "renders the same profile surface for owner and other logged-in users", %{conn: conn} do
      profile_user = user_fixture()
      profile_scope = user_scope_fixture(profile_user)
      post = post_fixture(scope: profile_scope)
      owner_conn = log_in_user(conn, profile_user)
      viewer_conn = log_in_user(build_conn(), user_fixture())

      {:ok, owner_view, _html} = live(owner_conn, ~p"/u/#{profile_user.username}")
      {:ok, viewer_view, _html} = live(viewer_conn, ~p"/u/#{profile_user.username}")

      assert has_element?(owner_view, "#profile-show")
      assert has_element?(viewer_view, "#profile-show")
      refute has_element?(owner_view, "#profile-edit-link")
      refute has_element?(viewer_view, "#profile-edit-link")
      refute has_element?(owner_view, "#profile-stats")
      refute has_element?(viewer_view, "#profile-stats")
      refute has_element?(owner_view, "#profile-stats-private")
      refute has_element?(viewer_view, "#profile-stats-private")
      assert has_element?(owner_view, "#posts-#{post.id}")
      assert has_element?(viewer_view, "#posts-#{post.id}")
      refute has_element?(owner_view, "#home-post-delete-#{post.id}")
      refute has_element?(viewer_view, "#home-post-delete-#{post.id}")
    end

    test "returns not found for missing usernames", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/u/unknown_user")
      end
    end

    test "renders only the profile user's posts", %{conn: conn} do
      profile_user = user_fixture()
      profile_scope = user_scope_fixture(profile_user)
      profile_post = post_fixture(scope: profile_scope, body: "Profile post")
      other_post = post_fixture(body: "Other post")
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} = live(conn, ~p"/u/#{profile_user.username}")

      assert has_element?(view, "#profile-feed")
      assert has_element?(view, "#posts-#{profile_post.id}")
      refute has_element?(view, "#posts-#{other_post.id}")
    end

    test "allows comments on profile feed posts when viewer belongs to the gym", %{conn: conn} do
      profile_user = user_fixture()
      profile_scope = user_scope_fixture(profile_user)
      post = post_fixture(scope: profile_scope)
      viewer = user_fixture()
      viewer_scope = user_scope_fixture(viewer)
      {:ok, _membership} = Gyms.join_gym(viewer_scope, post.gym)
      conn = log_in_user(conn, viewer)

      {:ok, view, _html} = live(conn, ~p"/u/#{profile_user.username}")

      view
      |> form("#home-comment-form-#{post.id}",
        post_id: post.id,
        comment: %{body: "Profile feed reply."}
      )
      |> render_submit()

      assert [comment] = Feed.get_post(post.gym, post.id).comments
      assert has_element?(view, "#home-comment-#{comment.id}")
    end
  end

  describe "edit" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders profile edit form", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/profile")

      assert has_element?(view, "#profile-settings-form")
      assert has_element?(view, "input[name='user[username]'][value='#{user.username}']")
    end

    test "validates profile form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/profile")

      assert view
             |> form("#profile-settings-form", user: %{username: "not valid"})
             |> render_change() =~ "must use only lowercase letters, numbers, and underscores"
    end

    test "updates profile and navigates to username URL", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/profile")

      view
      |> form("#profile-settings-form",
        user: %{
          username: "fresh_send",
          display_name: "Fresh Send",
          bio: "Short and steep."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/u/fresh_send")

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.username == "fresh_send"
      assert updated_user.display_name == "Fresh Send"
      assert updated_user.bio == "Short and steep."
    end

    test "uploads an avatar", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/profile")

      upload =
        file_input(view, "#profile-settings-form", :avatar, [
          %{name: "avatar.jpg", content: "avatar image", type: "image/jpeg"}
        ])

      assert render_upload(upload, "avatar.jpg") =~ "100%"

      view
      |> form("#profile-settings-form",
        user: %{
          username: user.username,
          display_name: "Avatar User",
          bio: "Updated."
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/u/#{user.username}")

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.avatar_object_key =~ ~r/^users\/#{user.id}\//
    end
  end
end
