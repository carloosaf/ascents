defmodule Ascents.Ascents.Ascent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Feed.Post
  alias Ascents.Gyms.Gym
  alias Ascents.Routes.BoulderProblem
  alias Ascents.Sessions.Session

  schema "ascents" do
    field :climbed_at, :utc_datetime
    field :grade_snapshot, :string
    field :grade_scale_snapshot, :string
    field :post_type, :string, default: "ascent"
    field :deleted_at, :utc_datetime

    belongs_to :user, User
    belongs_to :gym, Gym
    belongs_to :boulder_problem, BoulderProblem
    belongs_to :post, Post
    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a structured ascent log entry.
  """
  def changeset(ascent, attrs) do
    ascent
    |> cast(attrs, [:climbed_at, :grade_snapshot, :grade_scale_snapshot, :deleted_at])
    |> validate_required([
      :user_id,
      :gym_id,
      :boulder_problem_id,
      :post_id,
      :post_type,
      :climbed_at,
      :grade_snapshot,
      :grade_scale_snapshot
    ])
    |> validate_length(:grade_snapshot, min: 1, max: 32)
    |> validate_length(:grade_scale_snapshot, min: 1, max: 32)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:gym_id)
    |> foreign_key_constraint(:boulder_problem_id)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:session_id)
    |> check_constraint(:post_type, name: :ascents_post_type_check)
    |> unique_constraint(:post_id, name: :ascents_post_id_index)
  end
end
