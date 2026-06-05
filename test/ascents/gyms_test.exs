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

  describe "get_gym!/1 and get_gym_by_slug/1" do
    test "loads gyms by id and normalized slug" do
      gym = gym_fixture(name: "Crux Central")

      assert Gyms.get_gym!(gym.id).id == gym.id
      assert Gyms.get_gym_by_slug(" CRUX-CENTRAL ").id == gym.id
      refute Gyms.get_gym_by_slug("missing")
      refute Gyms.get_gym_by_slug("")
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

  describe "authorization helpers" do
    test "reject anonymous and invalid inputs" do
      gym = gym_fixture()

      refute Gyms.member?(nil, gym)
      refute Gyms.owner?(nil, gym)
      refute Gyms.admin?(nil, gym)
      refute Gyms.moderator?(nil, gym)
      refute Gyms.can_update_gym?(nil, gym)
      refute Gyms.can_manage_routes?(nil, gym)
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
      refute Gyms.can_moderate_gym?(scope, gym)
      assert Gyms.can_post_in_gym?(scope, gym)
    end
  end
end
