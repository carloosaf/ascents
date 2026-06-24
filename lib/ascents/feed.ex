defmodule Ascents.Feed do
  @moduledoc """
  Gym-scoped social feed posts and comments.
  """

  import Ecto.Query, warn: false

  alias Ascents.Ascents, as: AscentLogs
  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Feed.{Comment, Post}
  alias Ascents.Gyms
  alias Ascents.Gyms.{Gym, GymMembership}
  alias Ascents.Repo

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.
  """
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end

  @doc """
  Lists visible posts for a gym with authors, gym, and visible comments preloaded.
  """
  def list_gym_posts(scope, %Gym{} = gym) do
    scope
    |> visible_posts_query()
    |> where([post], post.gym_id == ^gym.id)
    |> preload_for_feed()
    |> order_by([post], desc: post.inserted_at, desc: post.id)
    |> Repo.all()
  end

  def list_gym_posts(_scope, _gym), do: []

  @doc """
  Lists visible posts across gyms joined by the current user.
  """
  def list_home_posts(%Scope{user: %User{} = user} = scope) do
    scope
    |> visible_posts_query()
    |> join(:inner, [post], membership in GymMembership,
      on: membership.gym_id == post.gym_id and membership.user_id == ^user.id
    )
    |> preload_for_feed()
    |> order_by([post], desc: post.inserted_at, desc: post.id)
    |> Repo.all()
  end

  def list_home_posts(_scope), do: []

  @doc """
  Gets a visible home-feed post for the current user.
  """
  def get_home_post(%Scope{user: %User{} = user} = scope, id) do
    scope
    |> visible_posts_query()
    |> join(:inner, [post], membership in GymMembership,
      on: membership.gym_id == post.gym_id and membership.user_id == ^user.id
    )
    |> where([post], post.id == ^id)
    |> preload_for_feed()
    |> Repo.one()
  end

  def get_home_post(_scope, _id), do: nil

  @doc """
  Lists visible posts authored by a user with authors, gyms, and visible comments preloaded.
  """
  def list_user_posts(scope, %User{id: user_id}) do
    scope
    |> visible_posts_query()
    |> where([post], post.user_id == ^user_id)
    |> preload_for_feed()
    |> order_by([post], desc: post.inserted_at, desc: post.id)
    |> Repo.all()
  end

  def list_user_posts(_scope, _user), do: []

  @doc """
  Gets a gym-scoped post.
  """
  def get_post(scope, %Gym{} = gym, id) do
    scope
    |> visible_posts_query()
    |> where([post], post.gym_id == ^gym.id and post.id == ^id)
    |> preload_for_feed()
    |> Repo.one()
  end

  def get_post(_scope, _gym, _id), do: nil

  @doc """
  Gets a visible post authored by a user.
  """
  def get_user_post(scope, %User{id: user_id}, id) do
    scope
    |> visible_posts_query()
    |> where([post], post.user_id == ^user_id and post.id == ^id)
    |> preload_for_feed()
    |> Repo.one()
  end

  def get_user_post(_scope, _user, _id), do: nil

  @doc """
  Returns true when a post is visible to the current scope.

  Public posts are visible to everyone. Friends-only posts are visible only to
  their author and users with an accepted friendship with the author.
  """
  def can_view_post?(scope, %Post{id: post_id}) do
    scope
    |> visible_posts_query()
    |> where([post], post.id == ^post_id)
    |> Repo.exists?()
  end

  def can_view_post?(_scope, _post), do: false

  @doc """
  Gets a visible, non-deleted comment on a visible feed post.
  """
  def get_post_comment(scope, %Post{} = post, comment_id) do
    if can_view_post?(scope, post) do
      Comment
      |> where(
        [comment],
        comment.post_id == ^post.id and comment.id == ^comment_id and is_nil(comment.deleted_at)
      )
      |> preload([:user])
      |> Repo.one()
    end
  end

  def get_post_comment(_scope, _post, _comment_id), do: nil

  @doc """
  Creates a normal post inside a gym. Posting requires community membership.
  """
  def create_post(%Scope{user: %User{} = user} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)

    if Gyms.can_post_in_gym?(scope, gym) do
      %Post{gym_id: gym.id, user_id: user.id}
      |> Post.changeset(take_attrs(attrs, [:body, :image_object_key, :visibility]))
      |> Repo.insert()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def create_post(_scope, _gym, _attrs), do: {:error, :unauthorized}

  @doc """
  Creates a comment on a visible gym post. Commenting requires community membership.
  """
  def create_comment(%Scope{user: %User{} = user} = scope, %Gym{} = gym, %Post{} = post, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)
    visible_post = get_post(scope, gym, post.id)

    cond do
      is_nil(visible_post) ->
        {:error, :not_found}

      not Gyms.can_post_in_gym?(scope, gym) ->
        {:error, :unauthorized}

      true ->
        %Comment{post_id: visible_post.id, user_id: user.id}
        |> Comment.changeset(take_attrs(attrs, [:body]))
        |> Repo.insert()
        |> preload_result()
    end
  end

  def create_comment(_scope, _gym, _post, _attrs), do: {:error, :unauthorized}

  @doc """
  Returns true when the current user can delete a gym-scoped post.
  """
  def can_delete_post?(%Scope{user: %User{} = user} = scope, %Gym{} = gym, %Post{} = post) do
    post.gym_id == gym.id and (post.user_id == user.id or Gyms.can_moderate_gym?(scope, gym))
  end

  def can_delete_post?(_scope, _gym, _post), do: false

  @doc """
  Returns true when the current user can delete a gym-scoped comment.
  """
  def can_delete_comment?(
        %Scope{user: %User{} = user} = scope,
        %Gym{} = gym,
        %Post{} = post,
        %Comment{} = comment
      ) do
    post.gym_id == gym.id and comment.post_id == post.id and
      (comment.user_id == user.id or Gyms.can_moderate_gym?(scope, gym))
  end

  def can_delete_comment?(_scope, _gym, _post, _comment), do: false

  @doc """
  Soft-deletes a post. Content owners and gym moderators can delete it.
  """
  def delete_post(%Scope{user: %User{}} = scope, %Gym{} = gym, %Post{} = post) do
    stored_post = get_mutation_post(gym, post.id)

    cond do
      is_nil(stored_post) ->
        {:error, :not_found}

      not can_view_post?(scope, stored_post) and not Gyms.can_moderate_gym?(scope, gym) ->
        {:error, :not_found}

      not can_delete_post?(scope, gym, stored_post) ->
        {:error, :unauthorized}

      true ->
        stored_post
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
        |> Repo.update()
        |> tap(fn
          {:ok, deleted_post} -> AscentLogs.soft_delete_ascent_for_post(deleted_post)
          _result -> :ok
        end)
    end
  end

  def delete_post(_scope, _gym, _post), do: {:error, :unauthorized}

  @doc """
  Soft-deletes a comment. Content owners and gym moderators can delete it.
  """
  def delete_comment(
        %Scope{user: %User{}} = scope,
        %Gym{} = gym,
        %Post{} = post,
        %Comment{} = comment
      ) do
    stored_post = get_mutation_post(gym, post.id)
    stored_comment = get_mutation_comment(stored_post, comment.id)

    cond do
      is_nil(stored_post) or is_nil(stored_comment) ->
        {:error, :not_found}

      not can_view_post?(scope, stored_post) and not Gyms.can_moderate_gym?(scope, gym) ->
        {:error, :not_found}

      not can_delete_comment?(scope, gym, stored_post, stored_comment) ->
        {:error, :unauthorized}

      true ->
        stored_comment
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
        |> Repo.update()
    end
  end

  def delete_comment(_scope, _gym, _post, _comment), do: {:error, :unauthorized}

  defp visible_posts_query(%Scope{user: %User{id: user_id}}) do
    Post
    |> where([post], is_nil(post.deleted_at))
    |> where(
      [post],
      post.visibility == "public" or post.user_id == ^user_id or
        fragment(
          """
          EXISTS (
            SELECT 1
            FROM friendships AS friendship
            WHERE friendship.status = 'accepted'
              AND (
                (friendship.requester_id = ? AND friendship.recipient_id = ?)
                OR
                (friendship.recipient_id = ? AND friendship.requester_id = ?)
              )
          )
          """,
          post.user_id,
          ^user_id,
          post.user_id,
          ^user_id
        )
    )
  end

  defp visible_posts_query(_scope) do
    Post
    |> where([post], is_nil(post.deleted_at) and post.visibility == "public")
  end

  defp preload_for_feed(query) do
    preload(query, [
      :user,
      :gym,
      :boulder_problem,
      :ascent,
      comments:
        ^from(comment in Comment,
          where: is_nil(comment.deleted_at),
          order_by: [asc: comment.inserted_at, asc: comment.id],
          preload: [:user]
        )
    ])
  end

  defp get_mutation_post(%Gym{id: gym_id}, post_id) do
    Post
    |> where([post], post.id == ^post_id and post.gym_id == ^gym_id and is_nil(post.deleted_at))
    |> Repo.one()
  end

  defp get_mutation_comment(nil, _comment_id), do: nil

  defp get_mutation_comment(%Post{id: post_id}, comment_id) do
    Comment
    |> where(
      [comment],
      comment.id == ^comment_id and comment.post_id == ^post_id and is_nil(comment.deleted_at)
    )
    |> Repo.one()
  end

  defp preload_result({:ok, %Post{} = post}), do: {:ok, Repo.preload(post, [:user, :gym])}
  defp preload_result({:ok, %Comment{} = comment}), do: {:ok, Repo.preload(comment, [:user])}
  defp preload_result(result), do: result

  defp take_attrs(attrs, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      cond do
        Map.has_key?(attrs, key) ->
          Map.put(acc, key, Map.fetch!(attrs, key))

        Map.has_key?(attrs, Atom.to_string(key)) ->
          Map.put(acc, key, Map.fetch!(attrs, Atom.to_string(key)))

        true ->
          acc
      end
    end)
  end
end
