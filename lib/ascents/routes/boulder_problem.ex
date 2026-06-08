defmodule Ascents.Routes.BoulderProblem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Gyms.Gym
  alias Ascents.Routes.GradeScales

  schema "boulder_problems" do
    field :title, :string
    field :grade, :string
    field :color, :string
    field :description, :string
    field :active, :boolean, default: true
    field :image_object_key, :string
    field :archived_at, :utc_datetime

    belongs_to :gym, Gym

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for a gym-scoped boulder problem.
  """
  def changeset(boulder_problem, %Gym{} = gym, attrs) do
    boulder_problem
    |> cast(attrs, [
      :title,
      :grade,
      :color,
      :description,
      :active,
      :image_object_key,
      :archived_at
    ])
    |> put_change(:gym_id, gym.id)
    |> update_change(:title, &trim_string/1)
    |> update_change(:grade, &GradeScales.normalize_grade/1)
    |> update_change(:color, &trim_string/1)
    |> update_change(:description, &trim_string/1)
    |> update_change(:image_object_key, &trim_string/1)
    |> validate_required([:gym_id, :title, :grade, :color, :active])
    |> validate_length(:title, min: 2, max: 120)
    |> validate_length(:color, min: 2, max: 80)
    |> validate_length(:description, max: 1000)
    |> validate_length(:image_object_key, max: 1024)
    |> validate_inclusion(:grade, GradeScales.grades_for_scale(gym.grade_scale))
    |> foreign_key_constraint(:gym_id)
  end

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value
end
