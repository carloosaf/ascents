defmodule AscentsWeb.GymLive.Show do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias Ascents.Routes, as: ClimbingRoutes
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign_gym_state(gym)}
  end

  def handle_event("join", _params, socket) do
    if socket.assigns.current_scope do
      case Gyms.join_gym(socket.assigns.current_scope, socket.assigns.gym) do
        {:ok, _membership} ->
          {:noreply,
           socket
           |> put_flash(:info, "Joined #{socket.assigns.gym.name}.")
           |> assign_gym_state(socket.assigns.gym)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "You already belong to this gym.")}

        {:error, :unauthorized} ->
          {:noreply, redirect_to_login(socket)}
      end
    else
      {:noreply, redirect_to_login(socket)}
    end
  end

  def handle_event("leave", _params, socket) do
    case Gyms.leave_gym(socket.assigns.current_scope, socket.assigns.gym) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Left #{socket.assigns.gym.name}.")
         |> assign_gym_state(socket.assigns.gym)}

      {:error, :only_owner} ->
        {:noreply, put_flash(socket, :error, "The only owner cannot leave this gym.")}

      {:error, :not_member} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not a member of this gym.")
         |> assign_gym_state(socket.assigns.gym)}

      {:error, :unauthorized} ->
        {:noreply, redirect_to_login(socket)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="gym-show" class="space-y-8">
        <.gym_header
          name={@gym.name}
          location={@gym.location || "Location TBD"}
          members={Integer.to_string(@member_count)}
          active_routes={Integer.to_string(@active_route_count)}
        />

        <section class="flex flex-wrap items-center justify-between gap-4">
          <div class="flex flex-wrap gap-2">
            <span class="rounded-md border border-ascents-line bg-ascents-panel px-3 py-1.5 text-sm font-bold text-ascents-chalk">
              {grade_scale_label(@gym.grade_scale)}
            </span>
            <span
              :if={@membership}
              class="rounded-md bg-ascents-tape px-3 py-1.5 text-sm font-black text-ascents-tape-content"
            >
              {@membership.role}
            </span>
          </div>

          <div class="flex flex-wrap gap-3">
            <.button :if={!@current_scope} navigate={~p"/users/log-in"} variant="secondary">
              Log in to join
            </.button>
            <.button
              :if={@current_scope && !@membership}
              id="gym-join-button"
              phx-click="join"
              variant="primary"
            >
              <.icon name="hero-user-plus" class="size-4" /> Join gym
            </.button>
            <.button
              :if={@current_scope && @membership}
              id="gym-leave-button"
              phx-click="leave"
              variant="secondary"
            >
              <.icon name="hero-user-minus" class="size-4" /> Leave gym
            </.button>
            <.button
              :if={@can_manage_routes?}
              id="gym-routes-link"
              navigate={~p"/gyms/#{@gym.slug}/problems"}
              variant="secondary"
            >
              <.icon name="hero-map" class="size-4" /> Routes
            </.button>
            <.button
              :if={@can_update_gym?}
              id="gym-settings-link"
              navigate={~p"/gyms/#{@gym.slug}/settings"}
              variant="secondary"
            >
              <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
            </.button>
            <.button
              :if={@can_manage_members?}
              id="gym-members-link"
              navigate={~p"/gyms/#{@gym.slug}/members"}
              variant="secondary"
            >
              <.icon name="hero-users" class="size-4" /> Members
            </.button>
          </div>
        </section>

        <section class="chalk-panel relative rounded-lg border border-ascents-line p-6">
          <h2 class="text-lg font-black text-ascents-chalk">About</h2>
          <p id="gym-description" class="mt-3 max-w-3xl text-sm leading-6 text-ascents-chalk-soft">
            {@gym.description || "No description yet."}
          </p>
        </section>

        <section id="gym-active-routes" class="space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-black text-ascents-chalk">Active routes</h2>
              <p class="mt-1 text-sm text-ascents-muted">
                Current boulder problems for this gym.
              </p>
            </div>
            <.button
              :if={@can_manage_routes?}
              id="gym-new-route-link"
              navigate={~p"/gyms/#{@gym.slug}/problems/new"}
              variant="primary"
            >
              <.icon name="hero-plus" class="size-4" /> Add route
            </.button>
          </div>

          <.empty_state
            :if={@active_problems == []}
            title="No routes yet"
            description="Gym admins can add active boulder problems from route management."
            icon="hero-map"
          />

          <div
            :if={@active_problems != []}
            id="gym-active-route-list"
            class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
          >
            <.route_card
              :for={problem <- @active_problems}
              id={"gym-route-card-#{problem.id}"}
              title={problem.title}
              gym={@gym.name}
              grade={problem.grade}
              status="Active"
              meta={problem.description || problem.color}
            />
          </div>
        </section>

        <section class="grid gap-4 lg:grid-cols-2">
          <.empty_state
            title="No posts yet"
            description="Session notes and gym feed posts will appear here once feed workflows land."
            icon="hero-chat-bubble-left-right"
          />
          <.empty_state
            title="No ascents yet"
            description="Structured ascent history will use this gym's route data later."
            icon="hero-sparkles"
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_gym_state(socket, gym) do
    gym = Gyms.get_gym!(gym.id)
    current_scope = socket.assigns.current_scope

    assign(socket,
      gym: gym,
      membership: Gyms.get_membership(current_scope, gym),
      member_count: Gyms.count_gym_memberships(gym),
      active_route_count: ClimbingRoutes.count_active_boulder_problems(gym),
      active_problems: ClimbingRoutes.list_boulder_problems(gym),
      can_update_gym?: Gyms.can_update_gym?(current_scope, gym),
      can_manage_members?: Gyms.can_manage_members?(current_scope, gym),
      can_manage_routes?: Gyms.can_manage_routes?(current_scope, gym)
    )
  end

  defp redirect_to_login(socket) do
    socket
    |> put_flash(:error, "You must log in to join this gym.")
    |> push_navigate(to: ~p"/users/log-in")
  end

  defp grade_scale_label("french"), do: "French bouldering"
  defp grade_scale_label(_grade_scale), do: "V scale"
end
