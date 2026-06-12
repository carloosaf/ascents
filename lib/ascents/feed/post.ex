defmodule Ascents.Feed.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed.Comment
  alias Ascents.Gyms.Gym
  alias Ascents.Routes.BoulderProblem

  @post_types ~w(normal ascent)

  schema "posts" do
    field :body, :string
    field :image_object_key, :string
    field :post_type, :string, default: "normal"
    field :deleted_at, :utc_datetime

    belongs_to :gym, Gym
    belongs_to :user, User
    belongs_to :boulder_problem, BoulderProblem
    has_many :comments, Comment
    has_one :ascent, Ascent

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a normal gym feed post.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :image_object_key])
    |> update_change(:body, &blank_to_nil/1)
    |> update_change(:image_object_key, &trim_string/1)
    |> validate_required([:gym_id, :user_id, :post_type])
    |> validate_inclusion(:post_type, @post_types)
    |> validate_body()
    |> validate_ascent_route()
    |> validate_length(:image_object_key, max: 1_024)
    |> foreign_key_constraint(:gym_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:boulder_problem_id)
    |> check_constraint(:post_type, name: :posts_post_type_check)
  end

  defp validate_body(changeset) do
    changeset =
      if get_field(changeset, :post_type) == "normal" do
        validate_required(changeset, [:body])
      else
        changeset
      end

    validate_length(changeset, :body, max: 2_000)
  end

  defp validate_ascent_route(changeset) do
    if get_field(changeset, :post_type) == "ascent" do
      validate_required(changeset, [:boulder_problem_id])
    else
      changeset
    end
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value
end
