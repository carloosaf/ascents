defmodule Ascents.MediaTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures

  alias Ascents.Feed
  alias Ascents.Gyms
  alias Ascents.Media
  alias Ascents.Media.TestStorage

  setup do
    TestStorage.reset!()
    :ok
  end

  test "uploads validated images under scoped object keys" do
    gym = gym_fixture()
    problem = boulder_problem_fixture(gym: gym)
    path = fixture_path("test-image.jpg")

    assert {:ok, key} = Media.upload_image({:problem, problem}, path, "problem.jpg", "image/jpeg")
    assert key =~ ~r/^problems\/#{problem.id}\//
    assert {:ok, "test image bytes\n", "image/jpeg"} = Media.get_object(key)
  end

  test "rejects unsupported image uploads" do
    gym = gym_fixture()

    assert {:error, :invalid_extension} =
             Media.upload_image(
               {:gym, gym},
               fixture_path("test-image.jpg"),
               "gym.gif",
               "image/jpeg"
             )

    assert {:error, :invalid_content_type} =
             Media.upload_image(
               {:gym, gym},
               fixture_path("test-image.jpg"),
               "gym.jpg",
               "image/gif"
             )
  end

  test "generates and verifies signed media URLs" do
    assert url = Media.signed_url("gyms/1/wall.jpg")
    token = url |> URI.parse() |> Map.fetch!(:path) |> Path.basename()

    assert Media.verify_token(token) == {:ok, "gyms/1/wall.jpg"}
    refute Media.signed_url("posts/1/private.jpg")
  end

  test "checks user avatar authorization against authenticated scopes" do
    user = user_fixture()

    assert Media.authorized?(user_scope_fixture(user), {:user, user})
    refute Media.authorized?(nil, {:user, user})
  end

  test "authorizes post URLs through the centralized feed visibility rules" do
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
      assert Media.authorized?(scope, {:post, public_post}) ==
               Feed.can_view_post?(scope, public_post)

      assert Media.signed_url(scope, {:post, public_post})
    end

    for {actor, scope} <- actors do
      expected? = actor in [:author, :friend]

      assert Media.authorized?(scope, {:post, friends_post}) ==
               Feed.can_view_post?(scope, friends_post)

      assert is_binary(Media.signed_url(scope, {:post, friends_post})) == expected?
    end
  end

  defp fixture_path(name) do
    Path.expand("../support/fixtures/files/#{name}", __DIR__)
  end
end
