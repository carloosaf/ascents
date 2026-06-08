defmodule AscentsWeb.ProblemLive.Index do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias Ascents.Routes, as: ClimbingRoutes
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)

    if Gyms.can_manage_routes?(current_scope, gym) do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:gym, gym)
       |> assign_problems()}
    else
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
          class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
        >
          <.empty_state
            :if={@problems == []}
            title="No routes yet"
            description="Create the first active boulder problem for this gym."
            icon="hero-map"
          />

          <article
            :for={problem <- @problems}
            id={"problem-admin-card-#{problem.id}"}
            class="chalk-panel relative rounded-lg border border-ascents-line p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <.grade_badge grade={problem.grade} />
                <h2 class="mt-3 text-lg font-black text-ascents-chalk">{problem.title}</h2>
                <p class="mt-1 text-sm text-ascents-muted">{problem.color}</p>
              </div>
              <span class={[
                "rounded-md px-2.5 py-1 text-xs font-black uppercase",
                problem.active && "bg-ascents-tape text-ascents-tape-content",
                !problem.active && "bg-ascents-panel-hover text-ascents-muted"
              ]}>
                {if(problem.active, do: "Active", else: "Archived")}
              </span>
            </div>

            <p class="mt-4 min-h-12 text-sm leading-6 text-ascents-chalk-soft">
              {problem.description || "No route notes yet."}
            </p>

            <div class="mt-4 flex flex-wrap gap-2">
              <.button
                id={"problem-edit-link-#{problem.id}"}
                navigate={~p"/gyms/#{@gym.slug}/problems/#{problem.id}/edit"}
                variant="secondary"
              >
                <.icon name="hero-pencil-square" class="size-4" /> Edit
              </.button>
              <.button
                :if={problem.active}
                id={"problem-archive-button-#{problem.id}"}
                phx-click="archive"
                phx-value-id={problem.id}
                variant="danger"
              >
                <.icon name="hero-archive-box" class="size-4" /> Archive
              </.button>
              <.button
                :if={!problem.active}
                id={"problem-reactivate-button-#{problem.id}"}
                phx-click="reactivate"
                phx-value-id={problem.id}
                variant="secondary"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Reactivate
              </.button>
            </div>
          </article>
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
