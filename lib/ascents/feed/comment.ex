defmodule Ascents.Feed.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Feed.Post

  schema "comments" do
    field :body, :string
    field :deleted_at, :utc_datetime

    belongs_to :post, Post
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a post comment.
  """
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> update_change(:body, &trim_string/1)
    |> validate_required([:body, :post_id, :user_id])
    |> validate_length(:body, min: 1, max: 1_000)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value
end
