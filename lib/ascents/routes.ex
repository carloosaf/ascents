defmodule Ascents.Routes do
  @moduledoc """
  The Routes context for gym-scoped boulder problems.
  """

  import Ecto.Query, warn: false

  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Gyms
  alias Ascents.Gyms.Gym
  alias Ascents.Repo
  alias Ascents.Routes.{BoulderProblem, GradeScales}

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking boulder problem changes.
  """
  def change_boulder_problem(%Gym{} = gym, %BoulderProblem{} = boulder_problem, attrs \\ %{}) do
    BoulderProblem.changeset(boulder_problem, gym, attrs)
  end

  @doc """
  Returns select options for the given gym's grade scale.
  """
  def grade_options(%Gym{} = gym), do: GradeScales.options_for_scale(gym.grade_scale)

  @doc """
  Lists boulder problems for a gym.
  """
  def list_boulder_problems(gym, opts \\ [])

  def list_boulder_problems(%Gym{} = gym, opts) do
    include_archived? = Keyword.get(opts, :include_archived, false)

    BoulderProblem
    |> where([problem], problem.gym_id == ^gym.id)
    |> maybe_active_only(include_archived?)
    |> order_by([problem],
      desc: problem.active,
      asc: problem.grade,
      asc: problem.title,
      asc: problem.id
    )
    |> Repo.all()
  end

  def list_boulder_problems(_gym, _opts), do: []

  @doc """
  Counts active boulder problems for a gym.
  """
  def count_active_boulder_problems(%Gym{} = gym) do
    BoulderProblem
    |> where([problem], problem.gym_id == ^gym.id and problem.active)
    |> select([problem], count(problem.id))
    |> Repo.one()
  end

  def count_active_boulder_problems(_gym), do: 0

  @doc """
  Gets a single gym-scoped boulder problem.
  """
  def get_boulder_problem(%Gym{} = gym, id) do
    Repo.get_by(BoulderProblem, id: id, gym_id: gym.id)
  end

  @doc """
  Gets a single gym-scoped boulder problem.

  Raises `Ecto.NoResultsError` if the boulder problem does not exist in the gym.
  """
  def get_boulder_problem!(%Gym{} = gym, id) do
    case get_boulder_problem(gym, id) do
      %BoulderProblem{} = problem -> problem
      nil -> raise Ecto.NoResultsError, queryable: BoulderProblem
    end
  end

  @doc """
  Creates a boulder problem inside a gym.
  """
  def create_boulder_problem(%Scope{user: %User{}} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)

    if Gyms.can_manage_routes?(scope, gym) do
      %BoulderProblem{}
      |> BoulderProblem.changeset(gym, create_attrs(attrs))
      |> Repo.insert()
    else
      {:error, :unauthorized}
    end
  end

  def create_boulder_problem(_scope, _gym, _attrs), do: {:error, :unauthorized}

  @doc """
  Updates a gym-scoped boulder problem.
  """
  def update_boulder_problem(%Scope{} = scope, %Gym{} = gym, %BoulderProblem{} = problem, attrs)
      when is_map(attrs) do
    gym = Gyms.get_gym!(gym.id)

    cond do
      not Gyms.can_manage_routes?(scope, gym) ->
        {:error, :unauthorized}

      problem.gym_id != gym.id ->
        {:error, :not_found}

      true ->
        problem
        |> BoulderProblem.changeset(gym, update_attrs(attrs))
        |> Repo.update()
    end
  end

  def update_boulder_problem(_scope, _gym, _problem, _attrs), do: {:error, :unauthorized}

  @doc """
  Archives a boulder problem while preserving it for historical ascents.
  """
  def archive_boulder_problem(%Scope{} = scope, %Gym{} = gym, %BoulderProblem{} = problem) do
    update_status(scope, gym, problem, %{active: false, archived_at: DateTime.utc_now(:second)})
  end

  def archive_boulder_problem(_scope, _gym, _problem), do: {:error, :unauthorized}

  @doc """
  Reactivates an archived boulder problem.
  """
  def reactivate_boulder_problem(%Scope{} = scope, %Gym{} = gym, %BoulderProblem{} = problem) do
    update_status(scope, gym, problem, %{active: true, archived_at: nil})
  end

  def reactivate_boulder_problem(_scope, _gym, _problem), do: {:error, :unauthorized}

  defp update_status(%Scope{} = scope, %Gym{} = gym, %BoulderProblem{} = problem, attrs) do
    gym = Gyms.get_gym!(gym.id)

    cond do
      not Gyms.can_manage_routes?(scope, gym) ->
        {:error, :unauthorized}

      problem.gym_id != gym.id ->
        {:error, :not_found}

      true ->
        problem
        |> BoulderProblem.changeset(gym, attrs)
        |> Repo.update()
    end
  end

  defp maybe_active_only(query, true), do: query
  defp maybe_active_only(query, false), do: where(query, [problem], problem.active)

  defp create_attrs(attrs) do
    attrs
    |> take_attrs([:title, :grade, :color, :description, :image_object_key])
    |> Map.put_new(:active, true)
  end

  defp update_attrs(attrs) do
    take_attrs(attrs, [:title, :grade, :color, :description, :image_object_key])
  end

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
end
