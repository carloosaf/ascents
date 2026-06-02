defmodule Ascents.GymsFixtures do
  @moduledoc """
  This module defines test helpers for creating gym community entities.
  """

  alias Ascents.Gyms

  import Ascents.AccountsFixtures

  def unique_gym_name, do: "Gym #{System.unique_integer([:positive])}"

  def valid_gym_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      description: "A friendly bouldering community.",
      grade_scale: "v_scale",
      location: "Madrid",
      name: unique_gym_name()
    })
  end

  def gym_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {scope, attrs} = Map.pop(attrs, :scope, user_scope_fixture())

    {:ok, gym} =
      scope
      |> Gyms.create_gym(valid_gym_attributes(attrs))

    gym
  end

  def member_membership_fixture(gym, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {scope, _attrs} = Map.pop(attrs, :scope, user_scope_fixture())

    {:ok, membership} = Gyms.join_gym(scope, gym)
    membership
  end
end
