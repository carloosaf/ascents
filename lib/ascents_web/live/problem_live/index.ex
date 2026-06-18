defmodule AscentsWeb.ProblemLive.Index do
  use AscentsWeb, :live_view

  alias Ascents.Routes, as: ClimbingRoutes
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)

    case ClimbingRoutes.get_management_gym(current_scope, slug) do
      {:ok, gym} ->
        {:ok,
         socket
         |> assign(:current_scope, current_scope)
         |> assign(:gym, gym)
         |> assign_problems()}

      {:error, :unauthorized, gym} ->
        {:ok,
         socket
         |> assign(:current_scope, current_scope)
         |> put_flash(:error, "You are not allowed to manage routes for this gym.")
         |> push_navigate(to: ~p"/gyms/#{gym.slug}")}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    problem = ClimbingRoutes.get_boulder_problem!(socket.assigns.gym, id)

    case ClimbingRoutes.archive_boulder_problem(
           socket.assigns.current_scope,
           socket.assigns.gym,
           problem
         ) do
      {:ok, _problem} ->
        {:noreply,
         socket
         |> put_flash(:info, "Boulder problem archived.")
         |> assign_problems()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not allowed to archive this route.")}
    end
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    problem = ClimbingRoutes.get_boulder_problem!(socket.assigns.gym, id)

    case ClimbingRoutes.reactivate_boulder_problem(
           socket.assigns.current_scope,
           socket.assigns.gym,
           problem
         ) do
      {:ok, _problem} ->
        {:noreply,
         socket
         |> put_flash(:info, "Boulder problem reactivated.")
         |> assign_problems()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not allowed to reactivate this route.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="problem-admin-index" class="space-y-6">
        <section class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p class="text-sm font-bold uppercase text-ascents-muted">Route management</p>
            <h1 class="ascents-display mt-2 text-4xl leading-none text-ascents-chalk">
              {@gym.name}
            </h1>
          </div>
          <div class="flex flex-wrap gap-3">
            <.button navigate={~p"/gyms/#{@gym.slug}/problems/new"} variant="primary">
              <.icon name="hero-plus" class="size-4" /> New route
            </.button>
            <.button navigate={~p"/gyms/#{@gym.slug}"} variant="secondary">
              <.icon name="hero-arrow-left" class="size-4" /> Gym page
            </.button>
          </div>
        </section>

        <section
          id="problem-admin-list"
          class="ascents-stagger grid gap-4 xl:grid-cols-2 2xl:grid-cols-3"
        >
          <.empty_state
            :if={@problems == []}
            title="No routes yet"
            description="Create the first active boulder problem for this gym."
            icon="hero-map"
          />

          <.route_admin_card
            :for={problem <- @problems}
            id={"problem-admin-card-#{problem.id}"}
            problem={problem}
            gym={@gym}
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_problems(socket) do
    assign(
      socket,
      :problems,
      ClimbingRoutes.list_boulder_problems(socket.assigns.gym, include_archived: true)
    )
  end
end
