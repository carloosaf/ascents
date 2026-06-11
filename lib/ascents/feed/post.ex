defmodule Ascents.Feed.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Feed.Comment
  alias Ascents.Gyms.Gym

  schema "posts" do
    field :body, :string
    field :image_object_key, :string
    field :deleted_at, :utc_datetime

    belongs_to :gym, Gym
    belongs_to :user, User
    has_many :comments, Comment

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a normal gym feed post.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :image_object_key])
    |> update_change(:body, &trim_string/1)
    |> update_change(:image_object_key, &trim_string/1)
    |> validate_required([:body, :gym_id, :user_id])
    |> validate_length(:body, min: 1, max: 2_000)
    |> validate_length(:image_object_key, max: 1_024)
    |> foreign_key_constraint(:gym_id)
    |> foreign_key_constraint(:user_id)
  end

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value
end
