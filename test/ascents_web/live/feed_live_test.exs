defmodule AscentsWeb.FeedLiveTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Accounts
  alias Ascents.Feed
  alias Ascents.Gyms

  describe "index" do
    test "redirects anonymous users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/feed")
    end

    test "renders an empty state for users without joined gym posts", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} = live(conn, ~p"/feed")

      assert has_element?(view, "#home-feed")
      assert has_element?(view, "[data-component='empty-state']")
    end

    test "renders posts from joined gyms only", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      joined_gym = gym_fixture()
      other_gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, joined_gym)
      joined_post = post_fixture(gym: joined_gym, body: "Joined post")
      other_post = post_fixture(gym: other_gym, body: "Other post")
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/feed")

      assert has_element?(view, "#posts-#{joined_post.id}")
      refute has_element?(view, "#posts-#{other_post.id}")
    end

    test "renders friends-only posts only for accepted friends in joined gyms", %{conn: _conn} do
      author = user_fixture()
      friend = user_fixture()
      non_friend = user_fixture()
      moderator = user_fixture()
      author_scope = user_scope_fixture(author)
      friend_scope = user_scope_fixture(friend)
      non_friend_scope = user_scope_fixture(non_friend)
      moderator_scope = user_scope_fixture(moderator)
      gym = gym_fixture()

      {:ok, _membership} = Gyms.join_gym(author_scope, gym)
      {:ok, _membership} = Gyms.join_gym(friend_scope, gym)
      {:ok, _membership} = Gyms.join_gym(non_friend_scope, gym)
      role_membership_fixture(gym, "mod", scope: moderator_scope)
      accepted_friendship_fixture(requester: author, recipient: friend)

      post =
        post_fixture(scope: author_scope, gym: gym, body: "Friends only", visibility: "friends")

      for viewer <- [author, friend] do
        {:ok, view, _html} = live(log_in_user(build_conn(), viewer), ~p"/feed")
        assert has_element?(view, "#posts-#{post.id}")
      end

      for viewer <- [non_friend, moderator] do
        {:ok, view, _html} = live(log_in_user(build_conn(), viewer), ~p"/feed")
        refute has_element?(view, "#posts-#{post.id}")
      end
    end

    test "renders profile pictures for post authors", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)

      {:ok, user} =
        Accounts.update_user_profile(scope, %{avatar_object_key: "users/1/avatar.jpg"})

      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      post = post_fixture(gym: gym, scope: scope, body: "Avatar post")
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/feed")

      assert has_element?(view, "#posts-#{post.id} [data-component='profile-picture'] img")

      refute has_element?(
               view,
               "#posts-#{post.id} [data-component='profile-picture'] .tape-label"
             )
    end

    test "allows comments from the joined feed", %{conn: conn} do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      post = post_fixture(gym: gym)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/feed")

      view
      |> form("#home-comment-form-#{post.id}",
        post_id: post.id,
        comment: %{body: "Home feed reply."}
      )
      |> render_submit()

      assert [comment] = Feed.get_post(scope, gym, post.id).comments
      assert has_element?(view, "#home-comment-#{comment.id}")
    end
  end
end
