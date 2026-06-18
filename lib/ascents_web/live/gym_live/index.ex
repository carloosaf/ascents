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

        <section class="ascents-stagger grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <.gym_card
            :for={gym <- @gyms}
            id={"gym-card-#{gym.id}"}
            gym={gym}
          />
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
end
