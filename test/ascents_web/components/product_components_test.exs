defmodule AscentsWeb.ProductComponentsTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Feed
  alias Ascents.Feed.Comment
  alias Ascents.Gyms

  test "grade badge renders a stable component marker" do
    document =
      (&AscentsWeb.ProductComponents.grade_badge/1)
      |> render_component(%{grade: "V5"})
      |> LazyHTML.from_fragment()

    badge = LazyHTML.query(document, "[data-component='grade-badge']")

    assert Enum.any?(badge)
    assert LazyHTML.text(badge) =~ "V5"
  end

  test "feed item renders social actions and optional bold grade" do
    document =
      (&AscentsWeb.ProductComponents.feed_item/1)
      |> render_component(%{
        id: "component-test-feed",
        author: "Mara Silva",
        gym: "Bloc District",
        time: "12 min ago",
        body: "Sent the blue cave project.",
        grade: "V5",
        comments: 9,
        reaction_count: 42
      })
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#component-test-feed") |> Enum.any?()
    assert document |> LazyHTML.query("[data-component='grade-badge']") |> Enum.any?()
    assert LazyHTML.text(document) =~ "Bloc District"
  end

  test "feed post renders media URLs only for scopes that can see the post" do
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

    public_post =
      post_fixture(
        scope: author_scope,
        gym: gym,
        visibility: "public",
        image_object_key: "posts/public.jpg"
      )

    friends_post =
      post_fixture(
        scope: author_scope,
        gym: gym,
        visibility: "friends",
        image_object_key: "posts/friends.jpg"
      )

    actors = [
      author: author_scope,
      friend: friend_scope,
      non_friend: non_friend_scope,
      anonymous: nil,
      moderator: moderator_scope
    ]

    for {_actor, scope} <- actors do
      assert public_post |> render_post(scope) |> has_post_image?(public_post)
    end

    for {actor, scope} <- actors do
      document = render_post(friends_post, scope)
      visible? = actor in [:author, :friend]

      assert has_post_image?(document, friends_post) == visible?

      unless visible? do
        html = LazyHTML.to_html(document)
        refute html =~ friends_post.image_object_key
        refute html =~ "/media/"
      end
    end
  end

  defp render_post(post, scope) do
    (&AscentsWeb.ProductComponents.feed_post/1)
    |> render_component(%{
      id: "post-#{post.id}",
      post: post,
      current_scope: scope,
      comment_form: Phoenix.Component.to_form(Feed.change_comment(%Comment{})),
      show_owner_actions: false
    })
    |> LazyHTML.from_fragment()
  end

  defp has_post_image?(document, post) do
    document
    |> LazyHTML.query("#home-post-image-#{post.id}[src*='/media/']")
    |> Enum.any?()
  end
end
