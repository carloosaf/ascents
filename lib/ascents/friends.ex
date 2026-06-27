defmodule Ascents.Friends do
  @moduledoc """
  Friend requests and accepted friendship relationships.
  """

  import Ecto.Query, warn: false

  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Friends.Friendship
  alias Ascents.Repo

  @relationship_list_limit 20
  @relationship_state_limit 20

  @doc """
  Sends a friend request to another user.

  A declined relationship may be replaced by a new pending request from either
  user. Pending and accepted relationships remain unique per unordered pair.
  """
  def send_request(%Scope{user: %User{} = requester}, %User{} = recipient) do
    cond do
      requester.id == recipient.id ->
        {:error, :cannot_friend_self}

      true ->
        transact(fn ->
          case get_pair(requester.id, recipient.id, lock: true) do
            nil ->
              %Friendship{requester_id: requester.id, recipient_id: recipient.id}
              |> Friendship.changeset(%{status: "pending", responded_at: nil})
              |> insert_or_rollback()

            %Friendship{status: "declined"} = friendship ->
              friendship
              |> Friendship.changeset(%{status: "pending", responded_at: nil})
              |> Ecto.Changeset.put_change(:requester_id, requester.id)
              |> Ecto.Changeset.put_change(:recipient_id, recipient.id)
              |> update_or_rollback()

            %Friendship{} ->
              Repo.rollback(:relationship_exists)
          end
        end)
        |> normalize_unique_pair_error()
        |> preload_result()
    end
  end

  def send_request(_scope, _recipient), do: {:error, :unauthorized}

  @doc """
  Accepts a pending request. Only its recipient may accept it.
  """
  def accept_request(%Scope{user: %User{} = user}, %Friendship{} = friendship) do
    transition_request(user, friendship, :recipient, "accepted")
  end

  def accept_request(_scope, _friendship), do: {:error, :unauthorized}

  @doc """
  Declines a pending request. Only its recipient may decline it.
  """
  def decline_request(%Scope{user: %User{} = user}, %Friendship{} = friendship) do
    transition_request(user, friendship, :recipient, "declined")
  end

  def decline_request(_scope, _friendship), do: {:error, :unauthorized}

  @doc """
  Cancels a pending request. Only its requester may cancel it.
  """
  def cancel_request(%Scope{user: %User{} = user}, %Friendship{} = friendship) do
    delete_relationship(user, friendship, :requester, "pending")
  end

  def cancel_request(_scope, _friendship), do: {:error, :unauthorized}

  @doc """
  Removes an accepted friendship. Either friend may remove it.
  """
  def remove_friend(%Scope{user: %User{} = user}, %Friendship{} = friendship) do
    delete_relationship(user, friendship, :either, "accepted")
  end

  def remove_friend(_scope, _friendship), do: {:error, :unauthorized}

  @doc """
  Lists accepted friends for the current user in username order.
  """
  def list_friends(%Scope{user: %User{} = user}) do
    User
    |> join(:inner, [friend], friendship in Friendship,
      on:
        friendship.status == "accepted" and
          ((friendship.requester_id == ^user.id and friendship.recipient_id == friend.id) or
             (friendship.recipient_id == ^user.id and friendship.requester_id == friend.id))
    )
    |> order_by([friend], asc: friend.username, asc: friend.id)
    |> limit(@relationship_list_limit)
    |> Repo.all()
  end

  def list_friends(_scope), do: []

  @doc """
  Lists pending requests received by the current user.
  """
  def list_incoming_requests(%Scope{user: %User{} = user}) do
    Friendship
    |> where([friendship], friendship.recipient_id == ^user.id and friendship.status == "pending")
    |> order_by([friendship], desc: friendship.inserted_at, desc: friendship.id)
    |> limit(@relationship_list_limit)
    |> preload([:requester, :recipient])
    |> Repo.all()
  end

  def list_incoming_requests(_scope), do: []

  @doc """
  Lists pending requests sent by the current user.
  """
  def list_outgoing_requests(%Scope{user: %User{} = user}) do
    Friendship
    |> where([friendship], friendship.requester_id == ^user.id and friendship.status == "pending")
    |> order_by([friendship], desc: friendship.inserted_at, desc: friendship.id)
    |> limit(@relationship_list_limit)
    |> preload([:requester, :recipient])
    |> Repo.all()
  end

  def list_outgoing_requests(_scope), do: []

  @doc """
  Returns relationship states for a bounded collection of users in one query.
  """
  def relationship_states(%Scope{user: %User{} = user}, users) when is_list(users) do
    users =
      users
      |> Enum.filter(&match?(%User{}, &1))
      |> Enum.uniq_by(& &1.id)
      |> Enum.take(@relationship_state_limit)

    user_ids = Enum.map(users, & &1.id)

    initial_states =
      Map.new(users, fn other_user ->
        state = if other_user.id == user.id, do: :self, else: :none
        {other_user.id, state}
      end)

    other_user_ids = Enum.reject(user_ids, &(&1 == user.id))

    if other_user_ids == [] do
      initial_states
    else
      Friendship
      |> where(
        [friendship],
        (friendship.requester_id == ^user.id and
           friendship.recipient_id in ^other_user_ids) or
          (friendship.recipient_id == ^user.id and
             friendship.requester_id in ^other_user_ids)
      )
      |> Repo.all()
      |> Enum.reduce(initial_states, fn friendship, states ->
        other_user_id = other_user_id(friendship, user.id)
        Map.put(states, other_user_id, relationship_state_for(friendship, user.id))
      end)
    end
  end

  def relationship_states(_scope, _users), do: %{}

  @doc """
  Returns the relationship record between the current user and another user.

  The lookup is scoped to the authenticated pair so callers cannot use it to
  inspect unrelated relationships.
  """
  def get_relationship(%Scope{user: %User{} = user}, %User{} = other_user)
      when user.id != other_user.id do
    case get_pair(user.id, other_user.id) do
      nil -> nil
      friendship -> Repo.preload(friendship, [:requester, :recipient])
    end
  end

  def get_relationship(_scope, _other_user), do: nil

  @doc """
  Returns the current user's relationship state with another user.
  """
  def relationship_state(%Scope{user: %User{} = user}, %User{} = other_user) do
    cond do
      user.id == other_user.id ->
        :self

      true ->
        case get_pair(user.id, other_user.id) do
          nil ->
            :none

          friendship ->
            relationship_state_for(friendship, user.id)
        end
    end
  end

  def relationship_state(_scope, _other_user), do: :unauthorized

  @doc """
  Returns true when two distinct users have an accepted friendship.
  """
  def friends?(%Scope{user: %User{} = user} = scope, %User{} = other_user) do
    user.id != other_user.id and relationship_state(scope, other_user) == :friends
  end

  def friends?(_scope, _other_user), do: false

  defp relationship_state_for(%Friendship{status: "accepted"}, _user_id), do: :friends
  defp relationship_state_for(%Friendship{status: "declined"}, _user_id), do: :declined

  defp relationship_state_for(
         %Friendship{status: "pending", requester_id: requester_id},
         requester_id
       ),
       do: :outgoing_pending

  defp relationship_state_for(%Friendship{status: "pending"}, _user_id), do: :incoming_pending

  defp other_user_id(%Friendship{requester_id: user_id, recipient_id: other_user_id}, user_id),
    do: other_user_id

  defp other_user_id(%Friendship{requester_id: other_user_id}, _user_id), do: other_user_id

  defp transition_request(user, friendship, owner, status) do
    transact(fn ->
      friendship = get_for_transition(friendship.id)

      with :ok <- authorize(friendship, user.id, owner),
           :ok <- require_status(friendship, "pending") do
        friendship
        |> Friendship.changeset(%{status: status, responded_at: DateTime.utc_now(:second)})
        |> update_or_rollback()
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> preload_result()
  end

  defp delete_relationship(user, friendship, owner, status) do
    transact(fn ->
      friendship = get_for_transition(friendship.id)

      with :ok <- authorize(friendship, user.id, owner),
           :ok <- require_status(friendship, status) do
        case Repo.delete(friendship) do
          {:ok, deleted_friendship} -> deleted_friendship
          {:error, changeset} -> Repo.rollback(changeset)
        end
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp authorize(nil, _user_id, _owner), do: {:error, :not_found}

  defp authorize(%Friendship{requester_id: user_id}, user_id, :requester), do: :ok
  defp authorize(%Friendship{recipient_id: user_id}, user_id, :recipient), do: :ok
  defp authorize(%Friendship{requester_id: user_id}, user_id, :either), do: :ok
  defp authorize(%Friendship{recipient_id: user_id}, user_id, :either), do: :ok
  defp authorize(%Friendship{}, _user_id, _owner), do: {:error, :unauthorized}

  defp require_status(%Friendship{status: status}, status), do: :ok
  defp require_status(%Friendship{}, _status), do: {:error, :invalid_transition}

  defp get_pair(first_user_id, second_user_id, opts \\ []) do
    query =
      Friendship
      |> where(
        [friendship],
        (friendship.requester_id == ^first_user_id and
           friendship.recipient_id == ^second_user_id) or
          (friendship.requester_id == ^second_user_id and
             friendship.recipient_id == ^first_user_id)
      )

    query =
      if Keyword.get(opts, :lock, false) do
        lock(query, "FOR UPDATE")
      else
        query
      end

    Repo.one(query)
  end

  defp get_for_transition(id) do
    Friendship
    |> where([friendship], friendship.id == ^id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp insert_or_rollback(changeset) do
    case Repo.insert(changeset) do
      {:ok, friendship} -> friendship
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp update_or_rollback(changeset) do
    case Repo.update(changeset) do
      {:ok, friendship} -> friendship
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp transact(fun) do
    case Repo.transact(fn -> {:ok, fun.()} end) do
      {:ok, friendship} -> {:ok, friendship}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_unique_pair_error({:error, %Ecto.Changeset{} = changeset} = error) do
    if Keyword.has_key?(changeset.errors, :requester_id) do
      {:error, :relationship_exists}
    else
      error
    end
  end

  defp normalize_unique_pair_error(result), do: result

  defp preload_result({:ok, %Friendship{} = friendship}) do
    {:ok, Repo.preload(friendship, [:requester, :recipient], force: true)}
  end

  defp preload_result(result), do: result
end
