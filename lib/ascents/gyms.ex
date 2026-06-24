defmodule Ascents.Gyms do
  @moduledoc """
  The Gyms context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Ascents.Accounts
  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Gyms.{Gym, GymMembership}
  alias Ascents.Repo

  @admin_roles ~w(owner admin)
  @moderator_roles ~w(owner admin mod)
  @member_roles ~w(owner admin mod member)
  @manageable_roles ~w(admin mod member)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking gym changes.
  """
  def change_gym(%Gym{} = gym, attrs \\ %{}) do
    Gym.changeset(gym, attrs)
  end

  @doc """
  Lists gyms in a deterministic order.
  """
  def list_gyms do
    Gym
    |> order_by([gym], asc: gym.name, asc: gym.id)
    |> Repo.all()
  end

  @doc """
  Gets a single gym.

  Raises `Ecto.NoResultsError` if the Gym does not exist.
  """
  def get_gym!(id), do: Repo.get!(Gym, id)

  @doc """
  Gets a gym by slug.
  """
  def get_gym_by_slug(slug) when is_binary(slug) do
    slug = normalize_slug(slug)

    if slug == "" do
      nil
    else
      Repo.get_by(Gym, slug: slug)
    end
  end

  def get_gym_by_slug(_slug), do: nil

  @doc """
  Gets a gym by slug with verification reviewers preloaded.
  """
  def get_verification_gym_by_slug!(slug) do
    slug
    |> get_gym_by_slug!()
    |> Repo.preload([:verification_requested_by_user, :verified_by_user])
  end

  @doc """
  Gets a gym by slug.

  Raises `Ecto.NoResultsError` if the Gym does not exist.
  """
  def get_gym_by_slug!(slug) do
    case get_gym_by_slug(slug) do
      %Gym{} = gym -> gym
      nil -> raise Ecto.NoResultsError, queryable: Gym
    end
  end

  @doc """
  Counts community memberships for a gym.
  """
  def count_gym_memberships(%Gym{id: gym_id}) do
    GymMembership
    |> where([membership], membership.gym_id == ^gym_id)
    |> select([membership], count(membership.id))
    |> Repo.one()
  end

  def count_gym_memberships(_gym), do: 0

  @doc """
  Creates a gym community and owner membership for the current user.
  """
  def create_gym(%Scope{user: %User{} = user}, attrs) when is_map(attrs) do
    now = DateTime.utc_now(:second)
    attrs = create_attrs(attrs)

    gym_changeset =
      %Gym{}
      |> Gym.changeset(Map.put(attrs, :slug, unique_slug(Map.get(attrs, :name))))

    Multi.new()
    |> Multi.insert(:gym, gym_changeset)
    |> Multi.insert(:owner_membership, fn %{gym: gym} ->
      membership_changeset(user, gym, "owner", now)
    end)
    |> Repo.transact()
    |> case do
      {:ok, %{gym: gym}} -> {:ok, gym}
      {:error, _operation, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def create_gym(_scope, _attrs), do: {:error, :unauthorized}

  @doc """
  Updates gym metadata.
  """
  def update_gym(%Scope{} = scope, %Gym{} = gym, attrs) when is_map(attrs) do
    gym = Repo.get!(Gym, gym.id)

    if can_update_gym?(scope, gym) do
      gym
      |> Gym.changeset(update_attrs(attrs))
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  def update_gym(_scope, _gym, _attrs), do: {:error, :unauthorized}

  @doc """
  Requests manual official ownership review for a community gym.

  Only a gym owner or gym admin may submit the claim. This transition never
  grants official status; a separately configured platform administrator must
  approve it.
  """
  def request_verification(%Scope{user: %User{} = user} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Repo.get!(Gym, gym.id)

    cond do
      not admin?(scope, gym) ->
        {:error, :unauthorized}

      gym.verification_status != "community" ->
        {:error, :invalid_transition}

      true ->
        gym
        |> Gym.verification_request_changeset(
          user,
          fetch_attr(attrs, :verification_request_note, fetch_attr(attrs, :note, "")),
          DateTime.utc_now(:second)
        )
        |> Repo.update()
    end
  end

  def request_verification(_scope, _gym, _attrs), do: {:error, :unauthorized}

  @doc """
  Approves a pending gym verification request.

  This is a platform-level privilege and is intentionally independent from
  gym-local owner/admin memberships.
  """
  def approve_verification(%Scope{user: %User{} = user} = scope, %Gym{} = gym, attrs)
      when is_map(attrs) do
    gym = Repo.get!(Gym, gym.id)

    cond do
      not Accounts.platform_admin?(scope) ->
        {:error, :unauthorized}

      gym.verification_status != "pending" ->
        {:error, :invalid_transition}

      true ->
        gym
        |> Gym.verification_approval_changeset(
          user,
          fetch_attr(attrs, :verification_note, fetch_attr(attrs, :note, "")),
          DateTime.utc_now(:second)
        )
        |> Repo.update()
    end
  end

  def approve_verification(_scope, _gym, _attrs), do: {:error, :unauthorized}

  @doc """
  Revokes an official gym badge and returns the page to community-owned state.
  """
  def revoke_verification(%Scope{} = scope, %Gym{} = gym) do
    gym = Repo.get!(Gym, gym.id)

    cond do
      not Accounts.platform_admin?(scope) ->
        {:error, :unauthorized}

      gym.verification_status != "verified" ->
        {:error, :invalid_transition}

      true ->
        gym
        |> Gym.verification_revoke_changeset()
        |> Repo.update()
    end
  end

  def revoke_verification(_scope, _gym), do: {:error, :unauthorized}

  @doc """
  Joins or follows a gym community for the current user.
  """
  def join_gym(%Scope{user: %User{} = user}, %Gym{} = gym) do
    user
    |> membership_changeset(gym, "member", DateTime.utc_now(:second))
    |> Repo.insert()
  end

  def join_gym(_scope, _gym), do: {:error, :unauthorized}

  @doc """
  Leaves or unfollows a gym community for the current user.
  """
  def leave_gym(%Scope{user: %User{} = user}, %Gym{} = gym) do
    case get_membership(user, gym) do
      nil ->
        {:error, :not_member}

      %GymMembership{role: "owner"} = membership ->
        if only_owner?(gym) do
          {:error, :only_owner}
        else
          Repo.delete(membership)
        end

      %GymMembership{} = membership ->
        Repo.delete(membership)
    end
  end

  def leave_gym(_scope, _gym), do: {:error, :unauthorized}

  @doc """
  Gets a user's membership in a gym community.
  """
  def get_membership(%Scope{user: %User{} = user}, %Gym{} = gym) do
    get_membership(user, gym)
  end

  def get_membership(%User{id: user_id}, %Gym{id: gym_id}) do
    Repo.get_by(GymMembership, user_id: user_id, gym_id: gym_id)
  end

  def get_membership(_user, _gym), do: nil

  @doc """
  Lists gym memberships with user data for owner/admin member management.
  """
  def list_gym_memberships(%Scope{} = scope, %Gym{} = gym) do
    if can_manage_members?(scope, gym) do
      memberships =
        GymMembership
        |> where([membership], membership.gym_id == ^gym.id)
        |> join(:inner, [membership], user in assoc(membership, :user))
        |> preload([_membership, user], user: user)
        |> order_by([membership, user],
          asc:
            fragment(
              "CASE ? WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 WHEN 'mod' THEN 2 ELSE 3 END",
              membership.role
            ),
          asc: user.username,
          asc: membership.id
        )
        |> Repo.all()

      {:ok, memberships}
    else
      {:error, :unauthorized}
    end
  end

  def list_gym_memberships(_scope, _gym), do: {:error, :unauthorized}

  @doc """
  Updates a non-owner gym membership role.
  """
  def update_membership_role(%Scope{} = scope, %Gym{} = gym, membership_id, role)
      when is_binary(role) do
    cond do
      not can_manage_members?(scope, gym) ->
        {:error, :unauthorized}

      role not in @manageable_roles ->
        {:error, :invalid_role}

      true ->
        case get_gym_membership(gym, membership_id) do
          nil ->
            {:error, :not_found}

          %GymMembership{role: "owner"} ->
            {:error, :owner_role_locked}

          %GymMembership{} = membership ->
            membership
            |> GymMembership.changeset(%{role: role, joined_at: membership.joined_at})
            |> Repo.update()
        end
    end
  end

  def update_membership_role(_scope, _gym, _membership_id, _role), do: {:error, :unauthorized}

  @doc """
  Removes a non-owner gym membership.
  """
  def remove_membership(%Scope{} = scope, %Gym{} = gym, membership_id) do
    cond do
      not can_manage_members?(scope, gym) ->
        {:error, :unauthorized}

      true ->
        case get_gym_membership(gym, membership_id) do
          nil ->
            {:error, :not_found}

          %GymMembership{role: "owner"} ->
            {:error, :owner_role_locked}

          %GymMembership{} = membership ->
            Repo.delete(membership)
        end
    end
  end

  def remove_membership(_scope, _gym, _membership_id), do: {:error, :unauthorized}

  @doc """
  Returns true when the current scope has any gym community membership.
  """
  def member?(scope, gym), do: has_role?(scope, gym, @member_roles)

  @doc """
  Returns true when the current scope owns the gym community.
  """
  def owner?(scope, gym), do: has_role?(scope, gym, ["owner"])

  @doc """
  Returns true when the current scope can manage gym settings and routes.
  """
  def admin?(scope, gym), do: has_role?(scope, gym, @admin_roles)

  @doc """
  Returns true when the current scope can moderate gym community content.
  """
  def moderator?(scope, gym), do: has_role?(scope, gym, @moderator_roles)

  @doc """
  Returns true when the current scope can update gym metadata.
  """
  def can_update_gym?(scope, gym), do: admin?(scope, gym)

  @doc """
  Returns true when the current scope can manage gym members and roles.
  """
  def can_manage_members?(scope, gym), do: admin?(scope, gym)

  @doc """
  Returns true when the current scope can manage boulder problems for the gym.
  """
  def can_manage_routes?(scope, gym), do: admin?(scope, gym)

  @doc """
  Returns true when the current scope can moderate gym posts and comments.
  """
  def can_moderate_gym?(scope, gym), do: moderator?(scope, gym)

  @doc """
  Returns true when the current scope can create posts inside the gym community.
  """
  def can_post_in_gym?(scope, gym), do: member?(scope, gym)

  @doc """
  Returns true when the current user may submit an ownership claim.
  """
  def can_request_verification?(scope, %Gym{verification_status: "community"} = gym) do
    admin?(scope, gym)
  end

  def can_request_verification?(_scope, _gym), do: false

  @doc """
  Returns true when the current user may approve or revoke official badges.
  """
  def can_review_verification?(scope), do: Accounts.platform_admin?(scope)

  @doc """
  Returns true when the current user may view the private claim workflow.
  """
  def can_access_verification_workflow?(scope, gym) do
    admin?(scope, gym) or can_review_verification?(scope)
  end

  defp membership_changeset(%User{} = user, %Gym{} = gym, role, joined_at) do
    %GymMembership{user_id: user.id, gym_id: gym.id}
    |> GymMembership.changeset(%{role: role, joined_at: joined_at})
  end

  defp has_role?(%Scope{user: %User{} = user}, %Gym{} = gym, roles) do
    case get_membership(user, gym) do
      %GymMembership{role: role} -> role in roles
      _membership -> false
    end
  end

  defp has_role?(_scope, _gym, _roles), do: false

  defp only_owner?(%Gym{id: gym_id}) do
    GymMembership
    |> where([membership], membership.gym_id == ^gym_id and membership.role == "owner")
    |> select([membership], count(membership.id))
    |> Repo.one()
    |> Kernel.==(1)
  end

  defp get_gym_membership(%Gym{id: gym_id}, membership_id) do
    Repo.get_by(GymMembership, id: membership_id, gym_id: gym_id)
  end

  defp create_attrs(attrs) do
    attrs
    |> take_attrs([:name, :description, :location, :image_object_key, :grade_scale])
    |> Map.put_new(:grade_scale, "v_scale")
  end

  defp update_attrs(attrs) do
    take_attrs(attrs, [:name, :description, :location, :image_object_key, :grade_scale])
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

  defp fetch_attr(attrs, key, default) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp unique_slug(name) do
    name
    |> slug_base()
    |> unique_slug_candidate()
  end

  defp unique_slug_candidate(base, suffix \\ 1) do
    candidate =
      if suffix == 1 do
        base
      else
        "#{base}-#{suffix}"
      end

    if Repo.exists?(from(gym in Gym, where: gym.slug == ^candidate)) do
      unique_slug_candidate(base, suffix + 1)
    else
      candidate
    end
  end

  defp slug_base(name) when is_binary(name) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    if slug == "", do: "gym", else: slug
  end

  defp slug_base(_name), do: "gym"

  defp normalize_slug(slug) do
    slug
    |> String.trim()
    |> String.downcase()
  end
end
