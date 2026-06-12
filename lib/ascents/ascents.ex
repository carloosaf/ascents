defmodule Ascents.Ascents do
  @moduledoc """
  The Ascents context for transactional ascent post logging.
  """

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed.Post
  alias Ascents.Gyms
  alias Ascents.Gyms.Gym
  alias Ascents.Repo
  alias Ascents.Routes
  alias Ascents.Routes.BoulderProblem

  @ascent_post_types %{
    body: :string,
    image_object_key: :string,
    boulder_problem_id: :integer,
    climbed_at: :string
  }

  @doc """
  Returns an `%Ecto.Changeset{}` for ascent post forms.
  """
  def change_ascent_post(attrs \\ %{}) do
    {%{}, @ascent_post_types}
    |> cast(attrs, Map.keys(@ascent_post_types))
    |> update_change(:body, &trim_string/1)
    |> update_change(:image_object_key, &trim_string/1)
    |> update_change(:climbed_at, &trim_string/1)
    |> validate_required([:boulder_problem_id, :climbed_at])
    |> validate_length(:body, max: 2_000)
    |> validate_length(:image_object_key, max: 1_024)
    |> validate_climbed_at()
  end

  @doc """
  Creates a feed post tagged as an ascent and a linked structured ascent record.
  """
  def create_ascent_post(%Scope{user: %User{} = user} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)
    changeset = change_ascent_post(attrs)

    cond do
      not Gyms.can_post_in_gym?(scope, gym) ->
        {:error, :unauthorized}

      not changeset.valid? ->
        {:error, changeset}

      true ->
        create_valid_ascent_post(user, gym, changeset)
    end
  end

  def create_ascent_post(_scope, _gym, _attrs), do: {:error, :unauthorized}

  @doc """
  Gets a single ascent by post.
  """
  def get_ascent_by_post(%Post{id: post_id}) do
    Repo.get_by(Ascent, post_id: post_id)
  end

  def get_ascent_by_post(_post), do: nil

  @doc """
  Soft-deletes the ascent linked to a post.
  """
  def soft_delete_ascent_for_post(%Post{id: post_id}) do
    now = DateTime.utc_now(:second)

    Ascent
    |> where([ascent], ascent.post_id == ^post_id and is_nil(ascent.deleted_at))
    |> Repo.update_all(set: [deleted_at: now])

    :ok
  end

  def soft_delete_ascent_for_post(_post), do: :ok

  defp create_valid_ascent_post(%User{} = user, %Gym{} = gym, changeset) do
    problem_id = get_field(changeset, :boulder_problem_id)

    case Routes.get_boulder_problem(gym, problem_id) do
      %BoulderProblem{active: true} = problem ->
        insert_ascent_post(user, gym, problem, changeset)

      %BoulderProblem{} ->
        {:error, add_error(changeset, :boulder_problem_id, "is archived")}

      nil ->
        {:error, add_error(changeset, :boulder_problem_id, "does not exist")}
    end
  end

  defp insert_ascent_post(%User{} = user, %Gym{} = gym, %BoulderProblem{} = problem, changeset) do
    climbed_at = parse_climbed_at!(get_field(changeset, :climbed_at))

    post_attrs =
      changeset
      |> apply_changes()
      |> Map.take([:body, :image_object_key])

    Multi.new()
    |> Multi.insert(:post, fn _changes ->
      %Post{
        gym_id: gym.id,
        user_id: user.id,
        post_type: "ascent",
        boulder_problem_id: problem.id
      }
      |> Post.changeset(post_attrs)
    end)
    |> Multi.insert(:ascent, fn %{post: post} ->
      %Ascent{
        user_id: user.id,
        gym_id: gym.id,
        boulder_problem_id: problem.id,
        post_id: post.id
      }
      |> Ascent.changeset(%{
        climbed_at: climbed_at,
        grade_snapshot: problem.grade,
        grade_scale_snapshot: gym.grade_scale
      })
    end)
    |> Repo.transact()
    |> case do
      {:ok, %{post: post, ascent: ascent}} ->
        {:ok, %{post: Repo.preload(post, [:user, :gym, :boulder_problem]), ascent: ascent}}

      {:error, _operation, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  defp validate_climbed_at(changeset) do
    validate_change(changeset, :climbed_at, fn :climbed_at, value ->
      case parse_climbed_at(value) do
        {:ok, _datetime} -> []
        :error -> [climbed_at: "is invalid"]
      end
    end)
  end

  defp parse_climbed_at!(value) do
    {:ok, datetime} = parse_climbed_at(value)
    datetime
  end

  defp parse_climbed_at(%DateTime{} = datetime), do: {:ok, DateTime.truncate(datetime, :second)}

  defp parse_climbed_at(value) when is_binary(value) do
    value
    |> normalize_datetime_local()
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, naive_datetime} -> {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
      {:error, _reason} -> :error
    end
  end

  defp parse_climbed_at(_value), do: :error

  defp normalize_datetime_local(value) do
    cond do
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/) -> value <> ":00"
      true -> value
    end
  end

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value
end
