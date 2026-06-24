defmodule Ascents.FriendsFixtures do
  @moduledoc """
  Test helpers for friendship relationships.
  """

  alias Ascents.Friends

  import Ascents.AccountsFixtures

  def friendship_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {requester, attrs} = Map.pop(attrs, :requester, user_fixture())
    {recipient, _attrs} = Map.pop(attrs, :recipient, user_fixture())

    {:ok, friendship} =
      requester
      |> user_scope_fixture()
      |> Friends.send_request(recipient)

    friendship
  end

  def accepted_friendship_fixture(attrs \\ %{}) do
    friendship = friendship_fixture(attrs)

    {:ok, friendship} =
      friendship.recipient
      |> user_scope_fixture()
      |> Friends.accept_request(friendship)

    friendship
  end

  def declined_friendship_fixture(attrs \\ %{}) do
    friendship = friendship_fixture(attrs)

    {:ok, friendship} =
      friendship.recipient
      |> user_scope_fixture()
      |> Friends.decline_request(friendship)

    friendship
  end
end
