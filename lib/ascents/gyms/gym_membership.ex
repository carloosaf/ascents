defmodule Ascents.Gyms.GymMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Gyms.Gym

  @roles ~w(owner admin mod member)

  schema "gym_memberships" do
    field :role, :string, default: "member"
    field :joined_at, :utc_datetime

    belongs_to :user, User
    belongs_to :gym, Gym

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for app-local gym community membership.
  """
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :joined_at])
    |> validate_required([:role, :joined_at, :user_id, :gym_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:user_id, :gym_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:gym_id)
    |> check_constraint(:role, name: :gym_memberships_role_check)
  end

  def roles, do: @roles
end
