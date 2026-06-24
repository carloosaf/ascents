defmodule Ascents.Sessions do
  @moduledoc """
  Transactional creation of gym-scoped climbing sessions and grouped ascents.
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
  alias Ascents.Sessions.Session

  @session_input_types %{
    title: :string,
    notes: :string,
    started_at: :utc_datetime,
    image_object_key: :string,
    visibility: :string,
    ascents: {:array, :map}
  }

  @ascent_input_types %{boulder_problem_id: :integer}

  @doc """
  Returns an `%Ecto.Changeset{}` for a session creation form.
  """
  def change_session(attrs \\ %{}) when is_map(attrs) do
    attrs =
      attrs
      |> take_attrs(Map.keys(@session_input_types))
      |> normalize_started_at()

    {%{visibility: "public"}, @session_input_types}
    |> cast(attrs, Map.keys(@session_input_types))
    |> update_change(:title, &trim_string/1)
    |> update_change(:notes, &trim_string/1)
    |> update_change(:image_object_key, &trim_string/1)
    |> validate_required([:title, :started_at, :visibility, :ascents])
    |> validate_length(:title, min: 1, max: 120)
    |> validate_length(:notes, max: 2_000)
    |> validate_length(:image_object_key, max: 1_024)
    |> validate_inclusion(:visibility, Post.visibilities())
    |> validate_length(:ascents, min: 1)
    |> validate_ascent_rows()
  end

  @doc """
  Creates one session post, one session, and all grouped ascents atomically.

  The current user and selected gym are always taken from the trusted scope and
  gym arguments. User-supplied ownership or foreign-key fields are ignored.
  """
  def create_session(%Scope{user: %User{} = user} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)
    changeset = change_session(attrs)

    cond do
      not Gyms.can_post_in_gym?(scope, gym) ->
        {:error, :unauthorized}

      not changeset.valid? ->
        {:error, changeset}

      true ->
        case resolve_problems(gym, changeset) do
          {:ok, problems} -> insert_session(user, gym, changeset, problems)
          {:error, message} -> {:error, add_error(changeset, :ascents, message)}
        end
    end
  end

  def create_session(_scope, _gym, _attrs), do: {:error, :unauthorized}

  defp resolve_problems(%Gym{} = gym, changeset) do
    changeset
    |> get_field(:ascents)
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {attrs, index}, {:ok, problems} ->
      row_changeset = ascent_row_changeset(attrs)
      problem_id = get_field(row_changeset, :boulder_problem_id)

      case Routes.get_boulder_problem(gym, problem_id) do
        %BoulderProblem{active: true} = problem ->
          {:cont, {:ok, [problem | problems]}}

        %BoulderProblem{} ->
          {:halt, {:error, "row #{index} references an archived route"}}

        nil ->
          {:halt, {:error, "row #{index} references a route outside this gym"}}
      end
    end)
    |> case do
      {:ok, problems} -> {:ok, Enum.reverse(problems)}
      error -> error
    end
  end

  defp insert_session(%User{} = user, %Gym{} = gym, changeset, problems) do
    session_attrs = apply_changes(changeset)

    multi =
      Multi.new()
      |> Multi.insert(:post, fn _changes ->
        %Post{
          gym_id: gym.id,
          user_id: user.id,
          post_type: "session"
        }
        |> Post.changeset(%{
          body: Map.get(session_attrs, :notes),
          image_object_key: Map.get(session_attrs, :image_object_key),
          visibility: session_attrs.visibility
        })
      end)
      |> Multi.insert(:session, fn %{post: post} ->
        %Session{
          user_id: user.id,
          gym_id: gym.id,
          post_id: post.id
        }
        |> Session.changeset(
          Map.take(session_attrs, [
            :title,
            :notes,
            :started_at,
            :image_object_key,
            :visibility
          ])
        )
      end)

    multi =
      problems
      |> Enum.with_index()
      |> Enum.reduce(multi, fn {problem, index}, multi ->
        Multi.insert(multi, {:ascent, index}, fn %{post: post, session: session} ->
          %Ascent{
            user_id: user.id,
            gym_id: gym.id,
            boulder_problem_id: problem.id,
            post_id: post.id,
            session_id: session.id
          }
          |> Ascent.changeset(%{
            climbed_at: session_attrs.started_at,
            grade_snapshot: problem.grade,
            grade_scale_snapshot: gym.grade_scale
          })
        end)
      end)

    multi
    |> Repo.transact()
    |> preload_result()
  end

  defp preload_result({:ok, %{post: post, session: session}}) do
    ascents_query =
      from(ascent in Ascent,
        where: is_nil(ascent.deleted_at),
        order_by: [asc: ascent.id]
      )

    session =
      Repo.preload(session, [
        :user,
        :gym,
        :post,
        ascents: {ascents_query, [:boulder_problem]}
      ])

    post =
      Repo.preload(post, [
        :user,
        :gym,
        session: [ascents: :boulder_problem]
      ])

    {:ok, %{session: session, post: post, ascents: session.ascents}}
  end

  defp preload_result({:error, _operation, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp preload_result({:error, _operation, reason, _changes}), do: {:error, reason}

  defp validate_ascent_rows(changeset) do
    validate_change(changeset, :ascents, fn :ascents, rows ->
      if Enum.all?(rows, &ascent_row_changeset(&1).valid?) do
        []
      else
        [ascents: "must contain valid route selections"]
      end
    end)
  end

  defp ascent_row_changeset(attrs) when is_map(attrs) do
    {%{}, @ascent_input_types}
    |> cast(take_attrs(attrs, Map.keys(@ascent_input_types)), Map.keys(@ascent_input_types))
    |> validate_required([:boulder_problem_id])
  end

  defp ascent_row_changeset(_attrs) do
    {%{}, @ascent_input_types}
    |> cast(%{}, Map.keys(@ascent_input_types))
    |> validate_required([:boulder_problem_id])
  end

  defp normalize_started_at(attrs) do
    case Map.fetch(attrs, :started_at) do
      {:ok, value} -> Map.put(attrs, :started_at, normalize_datetime(value))
      :error -> attrs
    end
  end

  defp normalize_datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp normalize_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp normalize_datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  defp normalize_datetime(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        value <> "T00:00:00Z"

      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/) ->
        value <> ":00Z"

      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) ->
        value <> "Z"

      true ->
        value
    end
  end

  defp normalize_datetime(value), do: value

  defp take_attrs(attrs, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      cond do
        Map.has_key?(attrs, key) ->
          Map.put(acc, key, Map.fetch!(attrs, key))

        Map.has_key?(attrs, Atom.to_string(key)) ->
          Map.put(acc, key, Map.fetch!(attrs, Atom.to_string(key)))

        true ->
          acc
      end
    end)
  end

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value
end
