defmodule Ascents.AscentsFixtures do
  @moduledoc """
  Test helpers for creating ascent post records.
  """

  alias Ascents.Ascents, as: AscentLogs

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures

  def valid_ascent_post_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      body: "Sent after three careful burns.",
      climbed_at: "2026-06-11T10:30",
      boulder_problem_id: nil
    })
  end

  def ascent_post_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {gym, attrs} = Map.pop_lazy(attrs, :gym, fn -> gym_fixture() end)
    {scope, attrs} = Map.pop_lazy(attrs, :scope, fn -> user_scope_fixture() end)
    {problem, attrs} = Map.pop_lazy(attrs, :problem, fn -> boulder_problem_fixture(gym: gym) end)

    ensure_membership(scope, gym)

    attrs =
      attrs
      |> valid_ascent_post_attributes()
      |> Map.put(:boulder_problem_id, problem.id)

    {:ok, result} = AscentLogs.create_ascent_post(scope, gym, attrs)
    result
  end

  defp ensure_membership(scope, gym) do
    unless Ascents.Gyms.get_membership(scope, gym) do
      {:ok, _membership} = Ascents.Gyms.join_gym(scope, gym)
    end
  end
end
