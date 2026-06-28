defmodule Ascents.FeedTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.FeedFixtures
  import Ascents.FriendsFixtures
  import Ascents.GymsFixtures

  alias Ascents.Feed
  alias Ascents.Feed.{Comment, Post}
  alias Ascents.Gyms
  alias Ascents.Repo

  describe "change_post/2 and change_comment/2" do
    test "return changesets" do
      assert %Ecto.Changeset{} = Feed.change_post(%Post{})
      assert %Ecto.Changeset{} = Feed.change_comment(%Comment{})
    end
  end

  describe "create_post/3" do
    test "requires gym membership" do
      gym = gym_fixture()
      scope = user_scope_fixture()

      assert Feed.create_post(scope, gym, valid_post_attributes()) == {:error, :unauthorized}
      assert Feed.create_post(nil, gym, valid_post_attributes()) == {:error, :unauthorized}
    end

    test "creates normal posts scoped to a gym and user" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:ok, post} =
               Feed.create_post(
                 scope,
                 gym,
                 valid_post_attributes(
                   body: "Big move on blue.",
                   image_object_key: "posts/1/a.jpg"
                 )
               )

      assert post.gym_id == gym.id
      assert post.user_id == user.id
      assert post.body == "Big move on blue."
      assert post.image_object_key == "posts/1/a.jpg"
      assert post.visibility == "public"
    end

    test "accepts public and friends visibility values" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      for visibility <- ~w(public friends) do
        assert {:ok, post} =
                 Feed.create_post(scope, gym, %{
                   body: "#{visibility} post",
                   visibility: visibility
                 })

        assert post.visibility == visibility
        assert post.gym_id == gym.id
      end
    end

    test "rejects invalid visibility values" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} =
               Feed.create_post(scope, gym, %{body: "Hidden", visibility: "private"})

      assert %{visibility: ["is invalid"]} = errors_on(changeset)
    end

    test "validates post body" do
      scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)

      assert {:error, changeset} = Feed.create_post(scope, gym, %{body: ""})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_gym_posts/1, list_home_posts/1, and list_user_posts/1" do
    test "lists visible gym posts newest first with associations" do
      gym = gym_fixture()
      other_gym = gym_fixture()
      first = post_fixture(gym: gym, body: "First")
      second = post_fixture(gym: gym, body: "Second")
      _other = post_fixture(gym: other_gym, body: "Other")

      assert Enum.map(Feed.list_gym_posts(nil, gym), & &1.id) == [second.id, first.id]

      assert [%Post{user: %Ascents.Accounts.User{}, gym: ^gym}] = [
               hd(Feed.list_gym_posts(nil, gym))
             ]
    end

    test "lists home posts only for joined gyms" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      joined_gym = gym_fixture()
      other_gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, joined_gym)
      joined_post = post_fixture(gym: joined_gym, body: "Joined")
      _other_post = post_fixture(gym: other_gym, body: "Other")

      assert Enum.map(Feed.list_home_posts(scope), & &1.id) == [joined_post.id]
    end

    test "lists visible user posts newest first with associations" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      other_scope = user_scope_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      first = post_fixture(scope: scope, gym: gym, body: "First profile post")
      second = post_fixture(scope: scope, gym: gym, body: "Second profile post")
      _other = post_fixture(scope: other_scope, gym: gym, body: "Other user's post")

      assert Enum.map(Feed.list_user_posts(scope, user), & &1.id) == [second.id, first.id]

      assert [
               %Post{
                 user: %Ascents.Accounts.User{id: user_id},
                 gym: ^gym,
                 comments: [],
                 ascent: _
               }
               | _
             ] = Feed.list_user_posts(scope, user)

      assert user_id == user.id
    end

    test "limits friends-only posts to the author and accepted friends across surfaces" do
      author = user_fixture()
      author_scope = user_scope_fixture(author)
      friend = user_fixture()
      friend_scope = user_scope_fixture(friend)
      unrelated_scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(author_scope, gym)
      {:ok, _membership} = Gyms.join_gym(friend_scope, gym)
      {:ok, _membership} = Gyms.join_gym(unrelated_scope, gym)
      accepted_friendship_fixture(requester: author, recipient: friend)

      {:ok, friends_post} =
        Feed.create_post(author_scope, gym, %{body: "Friends beta", visibility: "friends"})

      assert Feed.list_gym_posts(gym) == []
      assert Feed.get_post(gym, friends_post.id) == nil
      assert Feed.list_user_posts(author) == []
      assert Feed.get_user_post(author, friends_post.id) == nil

      assert Feed.list_gym_posts(gym, unrelated_scope) == []
      assert Feed.get_post(gym, friends_post.id, unrelated_scope) == nil
      assert Feed.list_home_posts(unrelated_scope) == []
      assert Feed.list_user_posts(author, unrelated_scope) == []
      assert Feed.get_user_post(author, friends_post.id, unrelated_scope) == nil

      assert Enum.map(Feed.list_gym_posts(gym, author_scope), & &1.id) == [friends_post.id]
      assert Feed.get_post(gym, friends_post.id, author_scope).id == friends_post.id
      assert Enum.map(Feed.list_home_posts(author_scope), & &1.id) == [friends_post.id]
      assert Enum.map(Feed.list_user_posts(author, author_scope), & &1.id) == [friends_post.id]
      assert Feed.get_user_post(author, friends_post.id, author_scope).id == friends_post.id

      assert Enum.map(Feed.list_gym_posts(gym, friend_scope), & &1.id) == [friends_post.id]
      assert Feed.get_post(gym, friends_post.id, friend_scope).id == friends_post.id
      assert Enum.map(Feed.list_home_posts(friend_scope), & &1.id) == [friends_post.id]
      assert Enum.map(Feed.list_user_posts(author, friend_scope), & &1.id) == [friends_post.id]
      assert Feed.get_user_post(author, friends_post.id, friend_scope).id == friends_post.id
    end
  end

  describe "create_comment/4" do
    test "requires gym membership" do
      post = post_fixture()
      scope = user_scope_fixture()

      assert Feed.create_comment(scope, post.gym, post, valid_comment_attributes()) ==
               {:error, :unauthorized}
    end

    test "creates comments on gym posts" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      post = post_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, post.gym)

      assert {:ok, comment} = Feed.create_comment(scope, post.gym, post, %{body: "Nice one"})

      assert comment.post_id == post.id
      assert comment.user_id == user.id
      assert comment.body == "Nice one"
    end

    test "rejects comments for a post from another gym" do
      post = post_fixture()
      other_gym = gym_fixture()
      scope = user_scope_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, other_gym)

      assert Feed.create_comment(scope, other_gym, post, valid_comment_attributes()) ==
               {:error, :not_found}
    end
  end

  describe "soft delete behavior" do
    test "soft-deletes owned posts and removes them from feeds" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, gym)
      {:ok, post} = Feed.create_post(scope, gym, %{body: "Owned"})

      assert {:ok, deleted_post} = Feed.delete_post(scope, gym, post)
      assert deleted_post.deleted_at
      assert Repo.get!(Post, post.id).deleted_at
      assert Feed.list_gym_posts(scope, gym) == []
      assert Feed.list_user_posts(scope, user) == []
    end

    test "rejects deleting someone else's post" do
      post = post_fixture()
      other_scope = user_scope_fixture()

      assert Feed.delete_post(other_scope, post.gym, post) == {:error, :unauthorized}
    end

    test "soft-deletes owned comments while preserving thread history" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      post = post_fixture()
      {:ok, _membership} = Gyms.join_gym(scope, post.gym)
      {:ok, comment} = Feed.create_comment(scope, post.gym, post, %{body: "Owned comment"})

      assert {:ok, deleted_comment} = Feed.delete_comment(scope, post.gym, post, comment)
      assert deleted_comment.deleted_at
      assert Repo.get!(Comment, comment.id).deleted_at

      reloaded_post = Feed.get_post(scope, post.gym, post.id)
      assert reloaded_post.comments == []
    end

    test "rejects deleting someone else's comment" do
      post = post_fixture()
      comment = comment_fixture(post: post, gym: post.gym)
      other_scope = user_scope_fixture()

      assert Feed.delete_comment(other_scope, post.gym, post, comment) == {:error, :unauthorized}
    end

    test "allows gym admins to moderate posts and comments" do
      author_scope = user_scope_fixture()
      gym = gym_fixture()
      {:ok, _membership} = Gyms.join_gym(author_scope, gym)
      {:ok, post} = Feed.create_post(author_scope, gym, %{body: "Admin cleanup"})
      {:ok, comment} = Feed.create_comment(author_scope, gym, post, %{body: "Needs cleanup"})
      admin_scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: admin_scope)

      assert {:ok, deleted_comment} = Feed.delete_comment(admin_scope, gym, post, comment)
      assert deleted_comment.deleted_at
      assert Feed.get_post(admin_scope, gym, post.id).comments == []

      assert {:ok, deleted_post} = Feed.delete_post(admin_scope, gym, post)
      assert deleted_post.deleted_at
      assert Feed.list_gym_posts(admin_scope, gym) == []
    end

    test "allows gym owners to clean up posts and comments" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      post = post_fixture(gym: gym)
      comment = comment_fixture(post: post, gym: gym)

      assert {:ok, deleted_comment} = Feed.delete_comment(owner_scope, gym, post, comment)
      assert deleted_comment.deleted_at

      assert {:ok, deleted_post} = Feed.delete_post(owner_scope, gym, post)
      assert deleted_post.deleted_at
      assert Feed.list_gym_posts(owner_scope, gym) == []
    end
  end
end
