defmodule Ascents.GymsTest do
  use Ascents.DataCase

  alias Ascents.Gyms
  alias Ascents.Gyms.{Gym, GymMembership}

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures

  describe "change_gym/2" do
    test "returns a gym changeset" do
      assert %Ecto.Changeset{} = changeset = Gyms.change_gym(%Gym{})
      assert changeset.required == [:name, :slug, :grade_scale]
    end
  end

  describe "create_gym/2" do
    test "requires an authenticated scope" do
      assert Gyms.create_gym(nil, valid_gym_attributes()) == {:error, :unauthorized}
    end

    test "validates required fields" do
      scope = user_scope_fixture()

      assert {:error, changeset} = Gyms.create_gym(scope, %{})

      assert %{
               name: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates gym fields" do
      scope = user_scope_fixture()

      attrs =
        valid_gym_attributes(
          description: String.duplicate("d", 501),
          grade_scale: "yds",
          location: String.duplicate("l", 161),
          name: "A",
          slug: "browser-controlled"
        )

      assert {:error, changeset} = Gyms.create_gym(scope, attrs)

      errors = errors_on(changeset)
      assert "should be at least 2 character(s)" in errors.name
      assert "should be at most 500 character(s)" in errors.description
      assert "should be at most 160 character(s)" in errors.location
      assert "is invalid" in errors.grade_scale
    end

    test "creates a gym and owner community membership transactionally" do
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert {:ok, gym} =
               Gyms.create_gym(
                 scope,
                 valid_gym_attributes(name: "The Arch", slug: "ignored-browser-slug")
               )

      assert gym.name == "The Arch"
      assert gym.slug == "the-arch"

      assert %GymMembership{role: "owner", user_id: user_id, gym_id: gym_id} =
               Gyms.get_membership(user, gym)

      assert user_id == user.id
      assert gym_id == gym.id
    end

    test "generates unique slugs for duplicate names" do
      scope = user_scope_fixture()
      attrs = valid_gym_attributes(name: "Bloc House")

      assert {:ok, first_gym} = Gyms.create_gym(scope, attrs)
      assert {:ok, second_gym} = Gyms.create_gym(scope, attrs)

      assert first_gym.slug == "bloc-house"
      assert second_gym.slug == "bloc-house-2"
    end
  end

  describe "list_gyms/0" do
    test "returns gyms ordered by name" do
      b_gym = gym_fixture(name: "Beta Gym")
      a_gym = gym_fixture(name: "Alpha Gym")

      assert Enum.map(Gyms.list_gyms(), & &1.id) == [a_gym.id, b_gym.id]
    end
  end

  describe "get_gym!/1, get_gym_by_slug/1, and get_gym_by_slug!/1" do
    test "loads gyms by id and normalized slug" do
      gym = gym_fixture(name: "Crux Central")

      assert Gyms.get_gym!(gym.id).id == gym.id
      assert Gyms.get_gym_by_slug(" CRUX-CENTRAL ").id == gym.id
      assert Gyms.get_gym_by_slug!(" CRUX-CENTRAL ").id == gym.id
      refute Gyms.get_gym_by_slug("missing")
      refute Gyms.get_gym_by_slug("")
    end

    test "raises for missing slug in bang lookup" do
      assert_raise Ecto.NoResultsError, fn ->
        Gyms.get_gym_by_slug!("missing")
      end
    end
  end

  describe "update_gym/3" do
    test "requires an authenticated scope" do
      gym = gym_fixture()

      assert Gyms.update_gym(nil, gym, %{name: "New"}) == {:error, :unauthorized}
    end

    test "allows the creator to update gym metadata without changing the slug" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(scope: scope, name: "Original Name")

      assert {:ok, updated_gym} =
               Gyms.update_gym(scope, gym, %{
                 name: "Updated Name",
                 slug: "ignored-update-slug",
                 description: "New description",
                 location: "Lisbon",
                 grade_scale: "french"
               })

      assert updated_gym.name == "Updated Name"
      assert updated_gym.slug == "original-name"
      assert updated_gym.description == "New description"
      assert updated_gym.location == "Lisbon"
      assert updated_gym.grade_scale == "french"
    end

    test "rejects users who are not owners" do
      gym = gym_fixture()
      other_scope = user_scope_fixture()

      assert Gyms.update_gym(other_scope, gym, %{name: "Nope"}) == {:error, :unauthorized}
    end

    test "allows admins to update gym metadata" do
      gym = gym_fixture(name: "Original Name")
      admin = user_fixture()
      admin_scope = user_scope_fixture(admin)
      role_membership_fixture(gym, "admin", scope: admin_scope)

      assert {:ok, updated_gym} = Gyms.update_gym(admin_scope, gym, %{name: "Admin Update"})
      assert updated_gym.name == "Admin Update"
    end

    test "rejects mods and members" do
      gym = gym_fixture()
      mod_scope = user_scope_fixture()
      member_scope = user_scope_fixture()

      role_membership_fixture(gym, "mod", scope: mod_scope)
      role_membership_fixture(gym, "member", scope: member_scope)

      assert Gyms.update_gym(mod_scope, gym, %{name: "Nope"}) == {:error, :unauthorized}
      assert Gyms.update_gym(member_scope, gym, %{name: "Nope"}) == {:error, :unauthorized}
    end
  end

  describe "gym ownership verification" do
    setup do
      previous_platform_admin_emails =
        Application.get_env(:ascents, :platform_admin_emails, :not_configured)

      Application.put_env(:ascents, :platform_admin_emails, ["platform-admin@example.com"])

      on_exit(fn ->
        case previous_platform_admin_emails do
          :not_configured ->
            Application.delete_env(:ascents, :platform_admin_emails)

          emails ->
            Application.put_env(:ascents, :platform_admin_emails, emails)
        end
      end)
    end

    test "new gyms default to community-managed without verification metadata" do
      gym = gym_fixture()

      assert gym.verification_status == "community"
      assert gym.verification_requested_at == nil
      assert gym.verification_requested_by_user_id == nil
      assert gym.verification_request_note == nil
      assert gym.verified_at == nil
      assert gym.verified_by_user_id == nil
      assert gym.verification_note == nil
    end

    test "gym owners can request verification and store pending metadata" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      assert {:ok, pending_gym} =
               Gyms.request_verification(owner_scope, gym, %{
                 note: "I operate this gym and can confirm through our official website."
               })

      assert pending_gym.verification_status == "pending"
      assert %DateTime{} = pending_gym.verification_requested_at
      assert pending_gym.verification_requested_by_user_id == owner.id

      assert pending_gym.verification_request_note ==
               "I operate this gym and can confirm through our official website."

      assert pending_gym.verified_at == nil
      assert pending_gym.verified_by_user_id == nil
    end

    test "platform administrators can approve pending requests" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      platform_admin = user_fixture(email: "platform-admin@example.com")
      platform_admin_scope = user_scope_fixture(platform_admin)

      assert {:ok, pending_gym} =
               Gyms.request_verification(owner_scope, gym, %{
                 note: "I operate this gym and can confirm through our official website."
               })

      assert {:ok, verified_gym} =
               Gyms.approve_verification(platform_admin_scope, pending_gym, %{
                 note: "Verified through the gym's published business contact."
               })

      assert verified_gym.verification_status == "verified"
      assert %DateTime{} = verified_gym.verified_at
      assert verified_gym.verified_by_user_id == platform_admin.id

      assert verified_gym.verification_note ==
               "Verified through the gym's published business contact."
    end

    test "only one concurrent platform administrator can approve a pending request" do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)

      assert {:ok, pending_gym} =
               Gyms.request_verification(owner_scope, gym, %{
                 note: "I operate this gym and can confirm through our official website."
               })

      admin_scopes =
        for email <- ["platform-admin@example.com", "second-platform-admin@example.com"] do
          user_scope_fixture(user_fixture(email: email))
        end

      Application.put_env(
        :ascents,
        :platform_admin_emails,
        Enum.map(admin_scopes, & &1.user.email)
      )

      parent = self()
      task_supervisor = start_supervised!(Task.Supervisor)

      tasks =
        Enum.map(admin_scopes, fn admin_scope ->
          Task.Supervisor.async_nolink(task_supervisor, fn ->
            send(parent, {:approval_ready, self()})

            receive do
              :approve ->
                Gyms.approve_verification(admin_scope, pending_gym, %{
                  note: "Concurrent review by #{admin_scope.user.email}"
                })
            end
          end)
        end)

      task_pids =
        for _admin_scope <- admin_scopes do
          assert_receive {:approval_ready, task_pid}
          task_pid
        end

      Enum.each(task_pids, &send(&1, :approve))
      results = Enum.map(tasks, &Task.await/1)

      assert Enum.count(results, &match?({:ok, %Gym{}}, &1)) == 1
      assert Enum.count(results, &(&1 == {:error, :invalid_transition})) == 1

      verified_gym = Gyms.get_gym!(gym.id)
      assert verified_gym.verification_status == "verified"
      assert verified_gym.verified_by_user_id in Enum.map(admin_scopes, & &1.user.id)
    end

    test "ordinary users and gym-local admins cannot approve requests" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      assert {:ok, pending_gym} =
               Gyms.request_verification(owner_scope, gym, %{
                 note: "I operate this gym and can confirm through our official website."
               })

      local_admin_scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: local_admin_scope)

      assert Gyms.approve_verification(owner_scope, pending_gym, %{note: "Self approved"}) ==
               {:error, :unauthorized}

      assert Gyms.approve_verification(local_admin_scope, pending_gym, %{
               note: "Gym admin approved"
             }) == {:error, :unauthorized}

      assert Gyms.get_gym!(gym.id).verification_status == "pending"
    end

    test "platform administrators can revoke verified gyms to community state" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      platform_admin = user_fixture(email: "platform-admin@example.com")
      platform_admin_scope = user_scope_fixture(platform_admin)

      {:ok, pending_gym} =
        Gyms.request_verification(owner_scope, gym, %{
          note: "I operate this gym and can confirm through our official website."
        })

      {:ok, verified_gym} =
        Gyms.approve_verification(platform_admin_scope, pending_gym, %{
          note: "Verified through the gym's published business contact."
        })

      assert {:ok, community_gym} =
               Gyms.revoke_verification(platform_admin_scope, verified_gym)

      assert community_gym.verification_status == "community"
      assert community_gym.verification_requested_at == nil
      assert community_gym.verification_requested_by_user_id == nil
      assert community_gym.verification_request_note == nil
      assert community_gym.verified_at == nil
      assert community_gym.verified_by_user_id == nil
      assert community_gym.verification_note == nil
    end

    test "owners, gym-local admins, and ordinary users cannot revoke verified gyms" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      platform_admin_scope = user_scope_fixture(user_fixture(email: "platform-admin@example.com"))

      local_admin_scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: local_admin_scope)
      ordinary_user_scope = user_scope_fixture()

      {:ok, pending_gym} =
        Gyms.request_verification(owner_scope, gym, %{
          note: "I operate this gym and can confirm through our official website."
        })

      {:ok, verified_gym} =
        Gyms.approve_verification(platform_admin_scope, pending_gym, %{
          note: "Verified through the gym's published business contact."
        })

      assert Gyms.revoke_verification(owner_scope, verified_gym) == {:error, :unauthorized}

      assert Gyms.revoke_verification(local_admin_scope, verified_gym) ==
               {:error, :unauthorized}

      assert Gyms.revoke_verification(ordinary_user_scope, verified_gym) ==
               {:error, :unauthorized}

      assert Gyms.get_gym!(gym.id).verification_status == "verified"
    end

    test "rejects verification requests from non-admin gym members" do
      gym = gym_fixture()
      member_scope = user_scope_fixture()
      role_membership_fixture(gym, "member", scope: member_scope)

      assert Gyms.request_verification(member_scope, gym, %{
               note: "I should not be able to claim this gym page."
             }) == {:error, :unauthorized}
    end
  end

  describe "join_gym/2" do
    test "requires an authenticated scope" do
      gym = gym_fixture()

      assert Gyms.join_gym(nil, gym) == {:error, :unauthorized}
    end

    test "creates a member community membership" do
      gym = gym_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert {:ok, membership} = Gyms.join_gym(scope, gym)
      assert membership.role == "member"
      assert membership.user_id == user.id
      assert membership.gym_id == gym.id
      assert %DateTime{} = membership.joined_at
    end

    test "rejects duplicate community memberships" do
      gym = gym_fixture()
      scope = user_scope_fixture()

      assert {:ok, _membership} = Gyms.join_gym(scope, gym)
      assert {:error, changeset} = Gyms.join_gym(scope, gym)
      assert "has already been taken" in errors_on(changeset).user_id
    end
  end

  describe "leave_gym/2" do
    test "requires an authenticated scope" do
      gym = gym_fixture()

      assert Gyms.leave_gym(nil, gym) == {:error, :unauthorized}
    end

    test "returns a domain error when the user has not joined" do
      gym = gym_fixture()
      scope = user_scope_fixture()

      assert Gyms.leave_gym(scope, gym) == {:error, :not_member}
    end

    test "allows a regular member to leave" do
      gym = gym_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)

      assert {:ok, membership} = Gyms.join_gym(scope, gym)
      assert {:ok, deleted_membership} = Gyms.leave_gym(scope, gym)
      assert deleted_membership.id == membership.id
      refute Gyms.get_membership(user, gym)
    end

    test "prevents the only owner from leaving" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(scope: scope)

      assert Gyms.leave_gym(scope, gym) == {:error, :only_owner}
      assert %GymMembership{role: "owner"} = Gyms.get_membership(user, gym)
    end
  end

  describe "list_gym_memberships/2" do
    test "requires owner or admin access" do
      gym = gym_fixture()
      member_scope = user_scope_fixture()
      role_membership_fixture(gym, "member", scope: member_scope)

      assert Gyms.list_gym_memberships(nil, gym) == {:error, :unauthorized}
      assert Gyms.list_gym_memberships(member_scope, gym) == {:error, :unauthorized}
    end

    test "returns ordered memberships with users preloaded" do
      owner = user_fixture(username: "owner_user")
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)

      member_scope = user_scope_fixture(user_fixture(username: "member_user"))
      mod_scope = user_scope_fixture(user_fixture(username: "mod_user"))
      admin_scope = user_scope_fixture(user_fixture(username: "admin_user"))

      role_membership_fixture(gym, "member", scope: member_scope)
      role_membership_fixture(gym, "mod", scope: mod_scope)
      role_membership_fixture(gym, "admin", scope: admin_scope)

      assert {:ok, memberships} = Gyms.list_gym_memberships(owner_scope, gym)
      assert Enum.map(memberships, & &1.role) == ["owner", "admin", "mod", "member"]

      assert Enum.map(memberships, & &1.user.username) == [
               "owner_user",
               "admin_user",
               "mod_user",
               "member_user"
             ]
    end
  end

  describe "update_membership_role/4" do
    test "requires owner or admin access" do
      gym = gym_fixture()
      member_scope = user_scope_fixture()
      membership = role_membership_fixture(gym, "member", scope: member_scope)

      assert Gyms.update_membership_role(nil, gym, membership.id, "mod") ==
               {:error, :unauthorized}

      assert Gyms.update_membership_role(member_scope, gym, membership.id, "mod") ==
               {:error, :unauthorized}
    end

    test "allows owners and admins to update non-owner roles" do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)
      membership = role_membership_fixture(gym, "member")

      assert {:ok, updated_membership} =
               Gyms.update_membership_role(owner_scope, gym, membership.id, "mod")

      assert updated_membership.role == "mod"

      admin_scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: admin_scope)

      assert {:ok, updated_membership} =
               Gyms.update_membership_role(admin_scope, gym, membership.id, "admin")

      assert updated_membership.role == "admin"
    end

    test "rejects invalid roles and missing memberships" do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)

      assert Gyms.update_membership_role(owner_scope, gym, -1, "mod") == {:error, :not_found}
      assert Gyms.update_membership_role(owner_scope, gym, -1, "owner") == {:error, :invalid_role}

      assert Gyms.update_membership_role(owner_scope, gym, -1, "spectator") ==
               {:error, :invalid_role}
    end

    test "does not allow changing owner memberships" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      owner_membership = Gyms.get_membership(owner, gym)

      assert Gyms.update_membership_role(owner_scope, gym, owner_membership.id, "admin") ==
               {:error, :owner_role_locked}

      assert Gyms.get_membership(owner, gym).role == "owner"
    end
  end

  describe "remove_membership/3" do
    test "requires owner or admin access" do
      gym = gym_fixture()
      member_scope = user_scope_fixture()
      membership = role_membership_fixture(gym, "member", scope: member_scope)

      assert Gyms.remove_membership(nil, gym, membership.id) == {:error, :unauthorized}
      assert Gyms.remove_membership(member_scope, gym, membership.id) == {:error, :unauthorized}
    end

    test "allows owners and admins to remove non-owner memberships" do
      owner_scope = user_scope_fixture()
      gym = gym_fixture(scope: owner_scope)
      membership = role_membership_fixture(gym, "member")

      assert {:ok, deleted_membership} = Gyms.remove_membership(owner_scope, gym, membership.id)
      assert deleted_membership.id == membership.id

      admin_scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: admin_scope)
      membership = role_membership_fixture(gym, "mod")

      assert {:ok, deleted_membership} = Gyms.remove_membership(admin_scope, gym, membership.id)
      assert deleted_membership.id == membership.id
    end

    test "rejects missing and owner memberships" do
      owner = user_fixture()
      owner_scope = user_scope_fixture(owner)
      gym = gym_fixture(scope: owner_scope)
      owner_membership = Gyms.get_membership(owner, gym)

      assert Gyms.remove_membership(owner_scope, gym, -1) == {:error, :not_found}

      assert Gyms.remove_membership(owner_scope, gym, owner_membership.id) ==
               {:error, :owner_role_locked}

      assert %GymMembership{role: "owner"} = Gyms.get_membership(owner, gym)
    end
  end

  describe "authorization helpers" do
    test "reject anonymous and invalid inputs" do
      gym = gym_fixture()

      refute Gyms.member?(nil, gym)
      refute Gyms.owner?(nil, gym)
      refute Gyms.admin?(nil, gym)
      refute Gyms.moderator?(nil, gym)
      refute Gyms.can_update_gym?(nil, gym)
      refute Gyms.can_manage_routes?(nil, gym)
      refute Gyms.can_manage_members?(nil, gym)
      refute Gyms.can_moderate_gym?(nil, gym)
      refute Gyms.can_post_in_gym?(nil, gym)

      scope = user_scope_fixture()
      refute Gyms.member?(scope, nil)
      refute Gyms.can_post_in_gym?(scope, nil)
    end

    test "reject non-members" do
      gym = gym_fixture()
      scope = user_scope_fixture()

      refute Gyms.member?(scope, gym)
      refute Gyms.owner?(scope, gym)
      refute Gyms.admin?(scope, gym)
      refute Gyms.moderator?(scope, gym)
      refute Gyms.can_update_gym?(scope, gym)
      refute Gyms.can_manage_routes?(scope, gym)
      refute Gyms.can_manage_members?(scope, gym)
      refute Gyms.can_moderate_gym?(scope, gym)
      refute Gyms.can_post_in_gym?(scope, gym)
    end

    test "allows all gym capabilities for owners" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      gym = gym_fixture(scope: scope)

      assert Gyms.member?(scope, gym)
      assert Gyms.owner?(scope, gym)
      assert Gyms.admin?(scope, gym)
      assert Gyms.moderator?(scope, gym)
      assert Gyms.can_update_gym?(scope, gym)
      assert Gyms.can_manage_routes?(scope, gym)
      assert Gyms.can_manage_members?(scope, gym)
      assert Gyms.can_moderate_gym?(scope, gym)
      assert Gyms.can_post_in_gym?(scope, gym)
    end

    test "allows admin management without owner-only capabilities" do
      gym = gym_fixture()
      scope = user_scope_fixture()
      role_membership_fixture(gym, "admin", scope: scope)

      assert Gyms.member?(scope, gym)
      refute Gyms.owner?(scope, gym)
      assert Gyms.admin?(scope, gym)
      assert Gyms.moderator?(scope, gym)
      assert Gyms.can_update_gym?(scope, gym)
      assert Gyms.can_manage_routes?(scope, gym)
      assert Gyms.can_manage_members?(scope, gym)
      assert Gyms.can_moderate_gym?(scope, gym)
      assert Gyms.can_post_in_gym?(scope, gym)
    end

    test "allows moderators to moderate and post but not manage routes or settings" do
      gym = gym_fixture()
      scope = user_scope_fixture()
      role_membership_fixture(gym, "mod", scope: scope)

      assert Gyms.member?(scope, gym)
      refute Gyms.owner?(scope, gym)
      refute Gyms.admin?(scope, gym)
      assert Gyms.moderator?(scope, gym)
      refute Gyms.can_update_gym?(scope, gym)
      refute Gyms.can_manage_routes?(scope, gym)
      refute Gyms.can_manage_members?(scope, gym)
      assert Gyms.can_moderate_gym?(scope, gym)
      assert Gyms.can_post_in_gym?(scope, gym)
    end

    test "allows members to post only" do
      gym = gym_fixture()
      scope = user_scope_fixture()
      role_membership_fixture(gym, "member", scope: scope)

      assert Gyms.member?(scope, gym)
      refute Gyms.owner?(scope, gym)
      refute Gyms.admin?(scope, gym)
      refute Gyms.moderator?(scope, gym)
      refute Gyms.can_update_gym?(scope, gym)
      refute Gyms.can_manage_routes?(scope, gym)
      refute Gyms.can_manage_members?(scope, gym)
      refute Gyms.can_moderate_gym?(scope, gym)
      assert Gyms.can_post_in_gym?(scope, gym)
    end
  end
end
