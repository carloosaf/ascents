defmodule Ascents.FeedVisibilityTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures

  alias Ascents.Feed
  alias Ascents.Gyms
  alias Ascents.Repo

  setup do
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
      post_fixture(scope: author_scope, gym: gym, body: "Public post", visibility: "public")

    friends_post =
      post_fixture(scope: author_scope, gym: gym, body: "Friends post", visibility: "friends")

    public_comment =
      comment_fixture(scope: author_scope, gym: gym, post: public_post, body: "Public comment")

    friends_comment =
      comment_fixture(scope: author_scope, gym: gym, post: friends_post, body: "Friends comment")

    %{
      author_scope: author_scope,
      friend_scope: friend_scope,
      non_friend_scope: non_friend_scope,
      moderator_scope: moderator_scope,
      author: author,
      gym: gym,
      public_post: public_post,
      friends_post: friends_post,
      public_comment: public_comment,
      friends_comment: friends_comment
    }
  end

  describe "scope-aware feed paths" do
    test "apply the owner/friend/non-friend/anonymous/moderator matrix", context do
      expected = %{
        owner: [context.friends_post.id, context.public_post.id],
        friend: [context.friends_post.id, context.public_post.id],
        non_friend: [context.public_post.id],
        anonymous: [context.public_post.id],
        moderator: [context.public_post.id]
      }

      scopes = %{
        owner: context.author_scope,
        friend: context.friend_scope,
        non_friend: context.non_friend_scope,
        anonymous: nil,
        moderator: context.moderator_scope
      }

      for {actor, scope} <- scopes do
        assert post_ids(Feed.list_gym_posts(scope, context.gym)) == expected[actor]
        assert post_ids(Feed.list_user_posts(scope, context.author)) == expected[actor]

        expected_home = if actor == :anonymous, do: [], else: expected[actor]
        assert post_ids(Feed.list_home_posts(scope)) == expected_home

        assert direct_post_ids(scope, context) == expected[actor]
      end
    end

    test "does not leak comments from a hidden friends-only post", context do
      assert Feed.get_post_comment(
               context.author_scope,
               context.friends_post,
               context.friends_comment.id
             )

      assert Feed.get_post_comment(
               context.friend_scope,
               context.friends_post,
               context.friends_comment.id
             )

      refute Feed.get_post_comment(
               context.non_friend_scope,
               context.friends_post,
               context.friends_comment.id
             )

      refute Feed.get_post_comment(nil, context.friends_post, context.friends_comment.id)

      refute Feed.get_post_comment(
               context.moderator_scope,
               context.friends_post,
               context.friends_comment.id
             )
    end
  end

  describe "comment and delete mutations" do
    test "allows comments only through visible posts and valid gym membership", context do
      assert {:ok, _comment} =
               Feed.create_comment(
                 context.author_scope,
                 context.gym,
                 context.friends_post,
                 %{body: "Author reply"}
               )

      assert {:ok, friend_comment} =
               Feed.create_comment(
                 context.friend_scope,
                 context.gym,
                 context.friends_post,
                 %{body: "Friend reply"}
               )

      assert {:ok, deleted_friend_comment} =
               Feed.delete_comment(
                 context.friend_scope,
                 context.gym,
                 context.friends_post,
                 friend_comment
               )

      assert deleted_friend_comment.deleted_at

      assert Feed.create_comment(
               context.non_friend_scope,
               context.gym,
               context.friends_post,
               %{body: "Blocked reply"}
             ) == {:error, :not_found}

      assert Feed.create_comment(
               context.moderator_scope,
               context.gym,
               context.friends_post,
               %{body: "Moderator reply"}
             ) == {:error, :not_found}

      assert Feed.create_comment(nil, context.gym, context.friends_post, %{body: "Anonymous"}) ==
               {:error, :unauthorized}
    end

    test "rejects unauthorized deletes without changing hidden rows", context do
      assert Feed.delete_post(context.friend_scope, context.gym, context.friends_post) ==
               {:error, :unauthorized}

      assert Feed.delete_post(context.non_friend_scope, context.gym, context.friends_post) ==
               {:error, :not_found}

      assert Feed.delete_post(nil, context.gym, context.friends_post) ==
               {:error, :unauthorized}

      assert Feed.delete_comment(
               context.friend_scope,
               context.gym,
               context.friends_post,
               context.friends_comment
             ) == {:error, :unauthorized}

      assert Feed.delete_comment(
               context.non_friend_scope,
               context.gym,
               context.friends_post,
               context.friends_comment
             ) == {:error, :not_found}

      assert Feed.delete_comment(
               nil,
               context.gym,
               context.friends_post,
               context.friends_comment
             ) == {:error, :unauthorized}

      refute Repo.reload!(context.friends_post).deleted_at
      refute Repo.reload!(context.friends_comment).deleted_at
    end

    test "keeps owner cleanup and explicit moderator cleanup", context do
      owner_post =
        post_fixture(
          scope: context.author_scope,
          gym: context.gym,
          body: "Owner cleanup",
          visibility: "friends"
        )

      assert {:ok, deleted_owner_post} =
               Feed.delete_post(context.author_scope, context.gym, owner_post)

      assert deleted_owner_post.deleted_at

      moderator_post =
        post_fixture(
          scope: context.author_scope,
          gym: context.gym,
          body: "Moderator cleanup",
          visibility: "friends"
        )

      moderator_comment =
        comment_fixture(
          scope: context.author_scope,
          gym: context.gym,
          post: moderator_post,
          body: "Moderated comment"
        )

      refute Feed.can_view_post?(context.moderator_scope, moderator_post)

      assert {:ok, deleted_comment} =
               Feed.delete_comment(
                 context.moderator_scope,
                 context.gym,
                 moderator_post,
                 moderator_comment
               )

      assert deleted_comment.deleted_at

      assert {:ok, deleted_post} =
               Feed.delete_post(context.moderator_scope, context.gym, moderator_post)

      assert deleted_post.deleted_at
    end
  end

  defp post_ids(posts), do: Enum.map(posts, & &1.id)

  defp direct_post_ids(scope, context) do
    [context.public_post, context.friends_post]
    |> Enum.filter(fn post ->
      Feed.get_post(scope, context.gym, post.id) &&
        Feed.get_user_post(scope, context.author, post.id)
    end)
    |> Enum.map(& &1.id)
    |> Enum.reverse()
  end
end
