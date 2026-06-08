defmodule Ascents.RoutesFixtures do
  @moduledoc """
  This module defines test helpers for creating boulder problem entities.
  """

  alias Ascents.Routes, as: ClimbingRoutes

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures

  def valid_boulder_problem_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      color: "Blue",
      description: "Steep start into a controlled top.",
      grade: "V3",
      image_object_key: nil,
      title: "Compression Line"
    })
  end

  def boulder_problem_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {gym, attrs} = Map.pop_lazy(attrs, :gym, fn -> gym_fixture() end)
    {scope, attrs} = Map.pop_lazy(attrs, :scope, fn -> owner_scope_for_gym(gym) end)

    {:ok, problem} =
      scope
      |> ClimbingRoutes.create_boulder_problem(gym, valid_boulder_problem_attributes(attrs))

    problem
  end

  defp owner_scope_for_gym(gym) do
    owner = user_fixture()
    scope = user_scope_fixture(owner)
    role_membership_fixture(gym, "admin", scope: scope)
    scope
  end
end
