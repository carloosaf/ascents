defmodule Ascents.FriendsTest do
  use Ascents.DataCase

  alias Ascents.Friends
  alias Ascents.Friends.Friendship

  import Ascents.AccountsFixtures
  import Ascents.FriendsFixtures

  describe "Friendship.changeset/2" do
    test "does not cast requester or recipient IDs" do
      requester = user_fixture()
      recipient = user_fixture()
      attacker = user_fixture()

      changeset =
        Friendship.changeset(
          %Friendship{requester_id: requester.id, recipient_id: recipient.id},
          %{
            requester_id: attacker.id,
            recipient_id: attacker.id,
            status: "pending"
          }
        )

      assert Ecto.Changeset.get_field(changeset, :requester_id) == requester.id
      assert Ecto.Changeset.get_field(changeset, :recipient_id) == recipient.id
    end
  end

  describe "send_request/2" do
    test "requires an authenticated scope" do
      assert Friends.send_request(nil, user_fixture()) == {:error, :unauthorized}
    end

    test "creates a pending request with server-owned user IDs" do
      requester = user_fixture()
      recipient = user_fixture()

      assert {:ok, friendship} =
               requester
               |> user_scope_fixture()
               |> Friends.send_request(recipient)

      assert friendship.requester_id == requester.id
      assert friendship.recipient_id == recipient.id
      assert friendship.status == "pending"
      assert friendship.responded_at == nil
      assert friendship.requester.id == requester.id
      assert friendship.recipient.id == recipient.id
    end

    test "prevents self-friending" do
      user = user_fixture()

      assert Friends.send_request(user_scope_fixture(user), user) ==
               {:error, :cannot_friend_self}
    end

    test "enforces one pending or accepted relationship per unordered pair" do
      requester = user_fixture()
      recipient = user_fixture()
      requester_scope = user_scope_fixture(requester)
      recipient_scope = user_scope_fixture(recipient)

      assert {:ok, friendship} = Friends.send_request(requester_scope, recipient)
      assert Friends.send_request(requester_scope, recipient) == {:error, :relationship_exists}
      assert Friends.send_request(recipient_scope, requester) == {:error, :relationship_exists}

      assert {:ok, accepted} = Friends.accept_request(recipient_scope, friendship)
      assert accepted.status == "accepted"
      assert Friends.send_request(requester_scope, recipient) == {:error, :relationship_exists}
      assert Friends.send_request(recipient_scope, requester) == {:error, :relationship_exists}
    end

    test "allows a declined pair to start a new request in either direction" do
      requester = user_fixture()
      recipient = user_fixture()
      friendship = declined_friendship_fixture(requester: requester, recipient: recipient)

      assert {:ok, renewed} =
               recipient
               |> user_scope_fixture()
               |> Friends.send_request(requester)

      assert renewed.id == friendship.id
      assert renewed.requester_id == recipient.id
      assert renewed.recipient_id == requester.id
      assert renewed.status == "pending"
      assert renewed.responded_at == nil
    end
  end

  describe "accept_request/2 and decline_request/2" do
    test "only the recipient can accept a pending request" do
      friendship = friendship_fixture()

      assert Friends.accept_request(user_scope_fixture(friendship.requester), friendship) ==
               {:error, :unauthorized}

      assert Friends.accept_request(user_scope_fixture(), friendship) ==
               {:error, :unauthorized}

      assert {:ok, accepted} =
               friendship.recipient
               |> user_scope_fixture()
               |> Friends.accept_request(friendship)

      assert accepted.status == "accepted"
      assert %DateTime{} = accepted.responded_at

      assert Friends.accept_request(user_scope_fixture(friendship.recipient), accepted) ==
               {:error, :invalid_transition}
    end

    test "only the recipient can decline a pending request" do
      friendship = friendship_fixture()

      assert Friends.decline_request(user_scope_fixture(friendship.requester), friendship) ==
               {:error, :unauthorized}

      assert {:ok, declined} =
               friendship.recipient
               |> user_scope_fixture()
               |> Friends.decline_request(friendship)

      assert declined.status == "declined"
      assert %DateTime{} = declined.responded_at

      assert Friends.decline_request(user_scope_fixture(friendship.recipient), declined) ==
               {:error, :invalid_transition}
    end

    test "does not trust a friendship struct supplied by the caller" do
      friendship = friendship_fixture()
      forged = %{friendship | recipient_id: friendship.requester_id}

      assert Friends.accept_request(user_scope_fixture(friendship.requester), forged) ==
               {:error, :unauthorized}
    end
  end

  describe "cancel_request/2" do
    test "only the requester can cancel a pending request" do
      friendship = friendship_fixture()

      assert Friends.cancel_request(user_scope_fixture(friendship.recipient), friendship) ==
               {:error, :unauthorized}

      assert {:ok, canceled} =
               friendship.requester
               |> user_scope_fixture()
               |> Friends.cancel_request(friendship)

      assert canceled.id == friendship.id

      assert Friends.relationship_state(
               user_scope_fixture(friendship.requester),
               friendship.recipient
             ) == :none
    end

    test "rejects cancellation after the request was accepted" do
      friendship = accepted_friendship_fixture()

      assert Friends.cancel_request(user_scope_fixture(friendship.requester), friendship) ==
               {:error, :invalid_transition}
    end
  end

  describe "remove_friend/2" do
    test "either user can remove an accepted friendship" do
      first = accepted_friendship_fixture()

      assert {:ok, removed} =
               first.requester
               |> user_scope_fixture()
               |> Friends.remove_friend(first)

      assert removed.id == first.id

      second = accepted_friendship_fixture()

      assert {:ok, removed} =
               second.recipient
               |> user_scope_fixture()
               |> Friends.remove_friend(second)

      assert removed.id == second.id
    end

    test "rejects non-friends and non-accepted requests" do
      friendship = friendship_fixture()

      assert Friends.remove_friend(user_scope_fixture(), friendship) == {:error, :unauthorized}

      assert Friends.remove_friend(user_scope_fixture(friendship.requester), friendship) ==
               {:error, :invalid_transition}
    end
  end

  describe "request and friend lists" do
    test "lists only the current user's pending incoming and outgoing requests" do
      current_user = user_fixture()
      sender = user_fixture(username: "sender")
      recipient = user_fixture(username: "recipient")
      unrelated = friendship_fixture()

      incoming = friendship_fixture(requester: sender, recipient: current_user)
      outgoing = friendship_fixture(requester: current_user, recipient: recipient)
      _declined = declined_friendship_fixture(requester: user_fixture(), recipient: current_user)

      assert [listed_incoming] = Friends.list_incoming_requests(user_scope_fixture(current_user))
      assert listed_incoming.id == incoming.id
      assert listed_incoming.requester.username == "sender"

      assert [listed_outgoing] = Friends.list_outgoing_requests(user_scope_fixture(current_user))
      assert listed_outgoing.id == outgoing.id
      assert listed_outgoing.recipient.username == "recipient"

      refute listed_incoming.id == unrelated.id
      refute listed_outgoing.id == unrelated.id
      assert Friends.list_incoming_requests(nil) == []
      assert Friends.list_outgoing_requests(nil) == []
    end

    test "lists accepted friends bidirectionally and excludes other states" do
      current_user = user_fixture()
      alpha = user_fixture(username: "alpha_friend")
      beta = user_fixture(username: "beta_friend")

      accepted_friendship_fixture(requester: current_user, recipient: beta)
      accepted_friendship_fixture(requester: alpha, recipient: current_user)
      friendship_fixture(requester: current_user, recipient: user_fixture())
      declined_friendship_fixture(requester: user_fixture(), recipient: current_user)

      assert Enum.map(Friends.list_friends(user_scope_fixture(current_user)), & &1.id) == [
               alpha.id,
               beta.id
             ]

      assert Friends.list_friends(nil) == []
    end
  end

  describe "relationship_state/2 and friends?/2" do
    test "reports directional pending, declined, accepted, self, and empty states" do
      requester = user_fixture()
      recipient = user_fixture()
      stranger = user_fixture()
      requester_scope = user_scope_fixture(requester)
      recipient_scope = user_scope_fixture(recipient)

      assert Friends.relationship_state(requester_scope, requester) == :self
      assert Friends.relationship_state(requester_scope, stranger) == :none
      assert Friends.relationship_state(nil, recipient) == :unauthorized

      assert {:ok, friendship} = Friends.send_request(requester_scope, recipient)
      assert Friends.relationship_state(requester_scope, recipient) == :outgoing_pending
      assert Friends.relationship_state(recipient_scope, requester) == :incoming_pending
      refute Friends.friends?(requester_scope, recipient)

      assert {:ok, declined} = Friends.decline_request(recipient_scope, friendship)
      assert Friends.relationship_state(requester_scope, recipient) == :declined
      assert Friends.relationship_state(recipient_scope, requester) == :declined

      assert {:ok, renewed} = Friends.send_request(requester_scope, recipient)
      assert renewed.id == declined.id
      assert {:ok, _accepted} = Friends.accept_request(recipient_scope, renewed)

      assert Friends.relationship_state(requester_scope, recipient) == :friends
      assert Friends.relationship_state(recipient_scope, requester) == :friends
      assert Friends.friends?(requester_scope, recipient)
      assert Friends.friends?(recipient_scope, requester)
      refute Friends.friends?(requester_scope, requester)
      refute Friends.friends?(nil, recipient)
    end
  end

  describe "get_relationship/2" do
    test "returns only the authenticated user's relationship with the supplied user" do
      current_user = user_fixture()
      profile_user = user_fixture()
      unrelated = friendship_fixture()
      friendship = friendship_fixture(requester: current_user, recipient: profile_user)
      scope = user_scope_fixture(current_user)

      assert Friends.get_relationship(scope, profile_user).id == friendship.id
      refute Friends.get_relationship(scope, profile_user).id == unrelated.id
      assert Friends.get_relationship(scope, current_user) == nil
      assert Friends.get_relationship(nil, profile_user) == nil
    end
  end
end
