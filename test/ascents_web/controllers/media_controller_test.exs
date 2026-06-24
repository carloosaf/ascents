defmodule AscentsWeb.MediaControllerTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures

  alias Ascents.Friends
  alias Ascents.Gyms
  alias Ascents.Media
  alias Ascents.Media.TestStorage

  setup do
    TestStorage.reset!()
    :ok
  end

  test "serves signed private media objects", %{conn: conn} do
    :ok = TestStorage.put_object("gyms/1/wall.jpg", "image body", "image/jpeg", [])

    token =
      Media.signed_url("gyms/1/wall.jpg") |> URI.parse() |> Map.fetch!(:path) |> Path.basename()

    conn = get(conn, ~p"/media/#{token}")

    assert response(conn, 200) == "image body"
    assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
  end

  test "rejects invalid media tokens without distinguishing them from missing objects", %{
    conn: conn
  } do
    conn = get(conn, ~p"/media/not-a-token")

    assert response(conn, 404) == "Not found"
  end

  test "rejects legacy object-key-only tokens for post media", %{conn: conn} do
    object_key = "posts/legacy-private.jpg"
    :ok = TestStorage.put_object(object_key, "private image", "image/jpeg", [])
    token = Phoenix.Token.sign(AscentsWeb.Endpoint, "media object access", object_key)

    conn = get(conn, ~p"/media/#{token}")

    assert response(conn, 404) == "Not found"
  end

  test "enforces the post audience matrix at the direct media endpoint" do
    context = post_media_context()

    public_url = Media.signed_url(context.author_scope, {:post, context.public_post})
    friends_url = Media.signed_url(context.author_scope, {:post, context.friends_post})

    actors = [
      author: context.author,
      friend: context.friend,
      non_friend: context.non_friend,
      anonymous: nil,
      moderator: context.moderator
    ]

    for {_actor, user} <- actors do
      assert media_response(public_url, user) == {200, "public image"}
    end

    for {actor, user} <- actors do
      expected =
        if actor in [:author, :friend], do: {200, "friends image"}, else: {404, "Not found"}

      assert media_response(friends_url, user) == expected
    end
  end

  test "rechecks friendship and object binding when a post token is replayed" do
    context = post_media_context()
    friends_url = Media.signed_url(context.friend_scope, {:post, context.friends_post})

    assert media_response(friends_url, context.friend) == {200, "friends image"}
    assert {:ok, _friendship} = Friends.remove_friend(context.author_scope, context.friendship)
    assert media_response(friends_url, context.friend) == {404, "Not found"}

    public_url = Media.signed_url(nil, {:post, context.public_post})

    context.public_post
    |> Ecto.Changeset.change(image_object_key: "posts/replaced.jpg")
    |> Ascents.Repo.update!()

    assert media_response(public_url, nil) == {404, "Not found"}
  end

  defp post_media_context do
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
    friendship = accepted_friendship_fixture(requester: author, recipient: friend)

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

    :ok = TestStorage.put_object(public_post.image_object_key, "public image", "image/jpeg", [])
    :ok = TestStorage.put_object(friends_post.image_object_key, "friends image", "image/jpeg", [])

    %{
      author: author,
      friend: friend,
      non_friend: non_friend,
      moderator: moderator,
      author_scope: author_scope,
      friend_scope: friend_scope,
      non_friend_scope: non_friend_scope,
      moderator_scope: moderator_scope,
      friendship: friendship,
      public_post: public_post,
      friends_post: friends_post
    }
  end

  defp media_response(url, user) do
    conn =
      Phoenix.ConnTest.build_conn()
      |> maybe_log_in(user)
      |> get(URI.parse(url).path)

    {conn.status, response(conn, conn.status)}
  end

  defp maybe_log_in(conn, nil), do: conn
  defp maybe_log_in(conn, user), do: log_in_user(conn, user)
end
