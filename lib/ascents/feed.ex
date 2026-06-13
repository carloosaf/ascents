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
  Lists visible posts for a gym with authors, gym, and comments preloaded.
  """
  def list_gym_posts(%Gym{} = gym) do
    Post
    |> where([post], post.gym_id == ^gym.id and is_nil(post.deleted_at))
    |> preload_for_feed()
    |> order_by([post], desc: post.inserted_at, desc: post.id)
    |> Repo.all()
  end

  def list_gym_posts(_gym), do: []

  @doc """
  Lists visible posts across gyms joined by the current user.
  """
  def list_home_posts(%Scope{user: %User{} = user}) do
    Post
    |> preload_for_feed()
    |> join(:inner, [post, _user, _gym], membership in GymMembership,
      on: membership.gym_id == post.gym_id and membership.user_id == ^user.id
    )
    |> where([post, _user, _gym, _membership], is_nil(post.deleted_at))
    |> order_by([post], desc: post.inserted_at, desc: post.id)
    |> Repo.all()
  end

  def list_home_posts(_scope), do: []

  @doc """
  Lists visible posts authored by a user with authors, gyms, and comments preloaded.
  """
  def list_user_posts(%User{id: user_id}) do
    Post
    |> where([post], post.user_id == ^user_id and is_nil(post.deleted_at))
    |> preload_for_feed()
    |> order_by([post], desc: post.inserted_at, desc: post.id)
    |> Repo.all()
  end

  def list_user_posts(_user), do: []

  @doc """
  Gets a gym-scoped post.
  """
  def get_post(%Gym{} = gym, id) do
    Post
    |> where([post], post.gym_id == ^gym.id and post.id == ^id)
    |> preload_for_feed()
    |> Repo.one()
  end

  def get_post(_gym, _id), do: nil

  @doc """
  Gets a visible post authored by a user.
  """
  def get_user_post(%User{id: user_id}, id) do
    Post
    |> where([post], post.user_id == ^user_id and post.id == ^id and is_nil(post.deleted_at))
    |> preload_for_feed()
    |> Repo.one()
  end

  def get_user_post(_user, _id), do: nil

  @doc """
  Creates a normal post inside a gym. Posting requires community membership.
  """
  def create_post(%Scope{user: %User{} = user} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)

    if Gyms.can_post_in_gym?(scope, gym) do
      %Post{gym_id: gym.id, user_id: user.id}
      |> Post.changeset(take_attrs(attrs, [:body, :image_object_key]))
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

    cond do
      not Gyms.can_post_in_gym?(scope, gym) ->
        {:error, :unauthorized}

      post.gym_id != gym.id or post.deleted_at ->
        {:error, :not_found}

      true ->
        %Comment{post_id: post.id, user_id: user.id}
        |> Comment.changeset(take_attrs(attrs, [:body]))
        |> Repo.insert()
        |> preload_result()
    end
  end

  def create_comment(_scope, _gym, _post, _attrs), do: {:error, :unauthorized}

  @doc """
  Soft-deletes a post. For now, only the content owner can delete it.
  """
  def delete_post(%Scope{user: %User{} = user}, %Gym{} = gym, %Post{} = post) do
    cond do
      post.gym_id != gym.id ->
        {:error, :not_found}

      post.user_id != user.id ->
        {:error, :unauthorized}

      true ->
        post
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
  Soft-deletes a comment. For now, only the content owner can delete it.
  """
  def delete_comment(
        %Scope{user: %User{} = user},
        %Gym{} = gym,
        %Post{} = post,
        %Comment{} = comment
      ) do
    cond do
      post.gym_id != gym.id or comment.post_id != post.id ->
        {:error, :not_found}

      comment.user_id != user.id ->
        {:error, :unauthorized}

      true ->
        comment
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
        |> Repo.update()
    end
  end

  def delete_comment(_scope, _gym, _post, _comment), do: {:error, :unauthorized}

  defp preload_for_feed(query) do
    query
    |> join(:inner, [post], user in assoc(post, :user))
    |> join(:inner, [post, _user], gym in assoc(post, :gym))
    |> preload([post, user, gym],
      user: user,
      gym: gym,
      boulder_problem: [],
      ascent: [],
      comments:
        ^from(comment in Comment,
          order_by: [asc: comment.inserted_at, asc: comment.id],
          preload: [:user]
        )
    )
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
