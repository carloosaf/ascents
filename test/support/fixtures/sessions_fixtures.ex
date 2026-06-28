defmodule Ascents.SessionsFixtures do
  @moduledoc """
  Test helpers for creating grouped climbing sessions.
  """

  alias Ascents.Sessions

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures

  def valid_session_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      notes: "Worked on tension and quiet feet.",
      started_at: "2026-06-23T18:30",
      image_object_key: "sessions/1/training.jpg",
      visibility: "public",
      ascents: []
    })
  end

  def session_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {gym, attrs} = Map.pop_lazy(attrs, :gym, fn -> gym_fixture() end)
    {scope, attrs} = Map.pop_lazy(attrs, :scope, fn -> user_scope_fixture() end)

    {problems, attrs} =
      Map.pop_lazy(attrs, :problems, fn -> [boulder_problem_fixture(gym: gym)] end)

    ensure_membership(scope, gym)

    attrs =
      attrs
      |> valid_session_attributes()
      |> Map.put(:ascents, Enum.map(problems, &%{boulder_problem_id: &1.id}))

    {:ok, result} = Sessions.create_session(scope, gym, attrs)
    result
  end

  defp ensure_membership(scope, gym) do
    unless Ascents.Gyms.get_membership(scope, gym) do
      {:ok, _membership} = Ascents.Gyms.join_gym(scope, gym)
    end
  end
end
