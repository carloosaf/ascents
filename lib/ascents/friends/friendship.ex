defmodule Ascents.Friends.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User

  @statuses ~w(pending accepted declined)

  schema "friendships" do
    field :status, :string, default: "pending"
    field :responded_at, :utc_datetime

    belongs_to :requester, User
    belongs_to :recipient, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a friendship changeset.

  Requester and recipient IDs are assigned by the context and are never cast
  from caller-provided attributes.
  """
  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:status, :responded_at])
    |> validate_required([:requester_id, :recipient_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_distinct_users()
    |> validate_response_timestamp()
    |> foreign_key_constraint(:requester_id)
    |> foreign_key_constraint(:recipient_id)
    |> unique_constraint(:requester_id, name: :friendships_user_pair_index)
    |> check_constraint(:requester_id, name: :friendships_distinct_users_check)
    |> check_constraint(:status, name: :friendships_status_check)
    |> check_constraint(:responded_at, name: :friendships_response_check)
  end

  def statuses, do: @statuses

  defp validate_distinct_users(changeset) do
    if get_field(changeset, :requester_id) == get_field(changeset, :recipient_id) do
      add_error(changeset, :recipient_id, "cannot be the same as requester")
    else
      changeset
    end
  end

  defp validate_response_timestamp(changeset) do
    case {get_field(changeset, :status), get_field(changeset, :responded_at)} do
      {"pending", nil} ->
        changeset

      {"pending", _responded_at} ->
        add_error(changeset, :responded_at, "must be empty while pending")

      {status, nil} when status in ["accepted", "declined"] ->
        add_error(changeset, :responded_at, "must be set after a response")

      _other ->
        changeset
    end
  end
end
