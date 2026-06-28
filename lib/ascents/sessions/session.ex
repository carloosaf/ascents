defmodule Ascents.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed.Post
  alias Ascents.Gyms.Gym

  schema "sessions" do
    field :notes, :string
    field :started_at, :utc_datetime
    field :image_object_key, :string
    field :visibility, :string, default: "public"
    field :post_type, :string, default: "session"
    field :deleted_at, :utc_datetime

    belongs_to :user, User
    belongs_to :gym, Gym
    belongs_to :post, Post
    has_many :ascents, Ascent

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a user-owned, gym-scoped climbing session.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:notes, :started_at, :image_object_key, :visibility, :deleted_at])
    |> update_change(:notes, &blank_to_nil/1)
    |> update_change(:image_object_key, &blank_to_nil/1)
    |> validate_required([
      :user_id,
      :gym_id,
      :post_id,
      :post_type,
      :started_at,
      :visibility
    ])
    |> validate_inclusion(:post_type, ["session"])
    |> validate_length(:notes, max: 2_000)
    |> validate_length(:image_object_key, max: 1_024)
    |> validate_inclusion(:visibility, Post.visibilities())
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:gym_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint(:post_id)
    |> check_constraint(:post_type, name: :sessions_post_type_check)
    |> check_constraint(:visibility, name: :sessions_visibility_check)
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value
end
