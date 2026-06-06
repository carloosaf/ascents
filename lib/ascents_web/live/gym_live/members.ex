defmodule AscentsWeb.GymLive.Members do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)

    if Gyms.can_manage_members?(current_scope, gym) do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:gym, gym)
       |> assign_memberships()}
    else
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> put_flash(:error, "You are not allowed to manage this gym's members.")
       |> push_navigate(to: ~p"/gyms/#{gym.slug}")}
    end
  end

  def handle_event("update_role", %{"membership_id" => membership_id, "role" => role}, socket) do
    case Gyms.update_membership_role(
           socket.assigns.current_scope,
           socket.assigns.gym,
           membership_id,
           role
         ) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member role updated.")
         |> assign_memberships()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, member_error(reason))}
    end
  end

  def handle_event("remove_member", %{"membership-id" => membership_id}, socket) do
    case Gyms.remove_membership(socket.assigns.current_scope, socket.assigns.gym, membership_id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member removed.")
         |> assign_memberships()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, member_error(reason))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="text-sm font-bold uppercase text-ascents-route-subtitle">{@gym.name}</p>
              <h1 class="ascents-display mt-2 text-5xl leading-none text-ascents-chalk">
                Members
              </h1>
              <p class="mt-4 max-w-2xl text-sm leading-6 text-ascents-chalk-soft">
                Manage community roles for admins, moderators, and members.
                Owner roles are locked until an ownership-transfer workflow is designed.
              </p>
            </div>
            <.button navigate={~p"/gyms/#{@gym.slug}"} variant="secondary">
              <.icon name="hero-arrow-left" class="size-4" /> Back to gym
            </.button>
          </div>
        </section>

        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line">
          <div class="overflow-x-auto">
            <table id="gym-members-table" class="w-full min-w-[44rem] text-left text-sm">
              <thead class="border-b border-ascents-line bg-ascents-panel-deep text-xs uppercase text-ascents-muted">
                <tr>
                  <th class="px-4 py-3">Member</th>
                  <th class="px-4 py-3">Role</th>
                  <th class="px-4 py-3">Joined</th>
                  <th class="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-ascents-line">
                <tr :for={membership <- @memberships} id={"gym-membership-#{membership.id}"}>
                  <td class="px-4 py-4">
                    <div class="font-bold text-ascents-chalk">{member_name(membership.user)}</div>
                    <div class="text-xs text-ascents-muted">/u/{membership.user.username}</div>
                  </td>
                  <td class="px-4 py-4">
                    <.form
                      for={to_form(%{"role" => membership.role})}
                      id={"membership-role-form-#{membership.id}"}
                      phx-change="update_role"
                    >
                      <input type="hidden" name="membership_id" value={membership.id} />
                      <.input
                        name="role"
                        type="select"
                        value={membership.role}
                        options={role_options()}
                        disabled={membership.role == "owner"}
                        class="w-36 rounded-md border border-ascents-line bg-ascents-panel-deep px-3 py-2 text-sm font-bold text-ascents-chalk outline-none transition focus:border-ascents-action focus:ring-2 focus:ring-ascents-action/20 disabled:cursor-not-allowed disabled:opacity-60"
                      />
                    </.form>
                  </td>
                  <td class="px-4 py-4 text-ascents-muted">
                    {Calendar.strftime(membership.joined_at, "%b %d, %Y")}
                  </td>
                  <td class="px-4 py-4 text-right">
                    <.button
                      id={"membership-remove-button-#{membership.id}"}
                      phx-click="remove_member"
                      phx-value-membership-id={membership.id}
                      variant="danger"
                      disabled={membership.role == "owner"}
                    >
                      <.icon name="hero-trash" class="size-4" /> Remove
                    </.button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_memberships(socket) do
    case Gyms.list_gym_memberships(socket.assigns.current_scope, socket.assigns.gym) do
      {:ok, memberships} -> assign(socket, :memberships, memberships)
      {:error, :unauthorized} -> assign(socket, :memberships, [])
    end
  end

  defp role_options do
    [{"Admin", "admin"}, {"Moderator", "mod"}, {"Member", "member"}]
  end

  defp member_name(user) do
    case user.display_name do
      name when is_binary(name) and name != "" -> name
      _ -> user.username
    end
  end

  defp member_error(:unauthorized), do: "You are not allowed to manage this gym's members."
  defp member_error(:invalid_role), do: "That role is not available."
  defp member_error(:not_found), do: "That membership could not be found."
  defp member_error(:owner_role_locked), do: "Owner memberships cannot be changed from this page."
  defp member_error(_reason), do: "Member update failed."
end
