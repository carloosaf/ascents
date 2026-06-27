defmodule Ascents.FeedFixtures do
  @moduledoc """
  Test helpers for gym feed posts and comments.
  """

  alias Ascents.Feed

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures

  def valid_post_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      body: "Fresh set on the cave wall."
    })
  end

  def valid_comment_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      body: "Good beta."
    })
  end

  def post_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {gym, attrs} = Map.pop_lazy(attrs, :gym, fn -> gym_fixture() end)
    {scope, attrs} = Map.pop_lazy(attrs, :scope, fn -> user_scope_fixture() end)

    ensure_membership(scope, gym)

    {:ok, post} = Feed.create_post(scope, gym, valid_post_attributes(attrs))
    Feed.get_post(gym, post.id, scope)
  end

  def comment_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {post, attrs} = Map.pop_lazy(attrs, :post, fn -> post_fixture() end)
    {gym, attrs} = Map.pop_lazy(attrs, :gym, fn -> post.gym end)
    {scope, attrs} = Map.pop_lazy(attrs, :scope, fn -> user_scope_fixture() end)

    ensure_membership(scope, gym)

    {:ok, comment} = Feed.create_comment(scope, gym, post, valid_comment_attributes(attrs))
    comment
  end

  defp ensure_membership(scope, gym) do
    unless Ascents.Gyms.get_membership(scope, gym) do
      {:ok, _membership} = Ascents.Gyms.join_gym(scope, gym)
    end
  end
end
