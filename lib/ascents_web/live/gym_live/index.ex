defmodule AscentsWeb.GymLive.Index do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias AscentsWeb.UserAuth

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, UserAuth.current_scope_from_session(session))
     |> assign(:gyms, Gyms.list_gyms())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="gyms-index" class="space-y-8">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <div class="relative z-10 flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <span class="tape-label bg-ascents-tape px-3 py-1 text-xs font-black uppercase text-ascents-tape-content">
                Gym communities
              </span>
              <h1 class="ascents-display mt-5 text-5xl leading-none text-ascents-chalk sm:text-6xl">
                Find your wall.
              </h1>
              <p class="mt-4 max-w-2xl text-sm leading-6 text-ascents-chalk-soft">
                Join a gym community to follow route updates, post session notes,
                and start logging ascents when route features land.
              </p>
            </div>

            <div class="flex flex-wrap gap-3">
              <.button :if={@current_scope} navigate={~p"/gyms/new"}>
                <.icon name="hero-plus" class="size-4" /> Create gym
              </.button>
              <.button :if={!@current_scope} navigate={~p"/users/log-in"} variant="secondary">
                Log in to create
              </.button>
            </div>
          </div>
        </section>

        <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <.link
            :for={gym <- @gyms}
            id={"gym-card-#{gym.id}"}
            navigate={~p"/gyms/#{gym.slug}"}
            class="chalk-panel group relative overflow-hidden rounded-lg border border-ascents-line p-5 transition hover:-translate-y-1 hover:border-ascents-action/60"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <p class="text-xs font-bold uppercase text-ascents-route-subtitle">
                  {gym.location || "Location TBD"}
                </p>
                <h2 class="mt-2 truncate text-xl font-black text-ascents-chalk">
                  {gym.name}
                </h2>
              </div>
              <span class="rounded-md border border-ascents-line bg-ascents-panel-deep px-2.5 py-1 text-xs font-bold text-ascents-muted">
                {grade_scale_label(gym.grade_scale)}
              </span>
            </div>
            <p class="mt-4 line-clamp-3 text-sm leading-6 text-ascents-chalk-soft">
              {gym.description || "No description yet."}
            </p>
            <p class="mt-5 inline-flex items-center gap-2 text-sm font-bold text-ascents-action transition group-hover:text-ascents-action-hover">
              Open community <.icon name="hero-arrow-right" class="size-4" />
            </p>
          </.link>
        </section>

        <.empty_state
          :if={@gyms == []}
          title="No gyms yet"
          description="Create the first climbing community and start shaping the local feed."
          icon="hero-building-storefront"
        />
      </div>
    </Layouts.app>
    """
  end

  defp grade_scale_label("french"), do: "French bouldering"
  defp grade_scale_label(_grade_scale), do: "V scale"
end
