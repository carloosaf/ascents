defmodule AscentsWeb.Dev.ComponentGalleryLive do
  use AscentsWeb, :live_view

  alias Ascents.Accounts
  alias Ascents.Accounts.Scope

  def mount(_params, session, socket) do
    current_scope =
      session
      |> Map.get("user_token")
      |> scope_from_token()

    form =
      %{
        "name" => "Moon Board Monday",
        "grade" => "V5",
        "notes" => "Fresh reset on the cave wall"
      }
      |> to_form(as: :route)

    {:ok, assign(socket, current_scope: current_scope, form: form)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="component-gallery" class="space-y-8">
        <section class="grid items-start gap-6 lg:grid-cols-[1.1fr_0.9fr]">
          <div class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
            <div class="absolute -right-10 top-8 hidden rotate-6 sm:block">
              <div class="tape-label h-10 w-40 bg-ascents-tape"></div>
              <div class="tape-label ml-16 mt-3 h-10 w-28 bg-grade-blue"></div>
              <div class="tape-label -ml-2 mt-3 h-10 w-36 bg-grade-pink"></div>
            </div>
            <p class="relative z-10 text-sm font-bold uppercase text-ascents-tape">Dev gallery</p>
            <h1 class="ascents-display relative z-10 mt-4 max-w-3xl text-4xl leading-none text-ascents-chalk sm:text-6xl">
              Ascents should feel like the gym feed after a good session.
            </h1>
            <p class="relative z-10 mt-5 max-w-2xl text-base leading-7 text-ascents-chalk-soft">
              Dark-first, playful, social, and balanced between media and text.
              Grades are bold anchors; people and route photos carry the story.
            </p>
            <div class="relative z-10 mt-6 flex flex-wrap gap-3">
              <.button>Post a send</.button>
              <.button variant="secondary">Browse routes</.button>
              <.button variant="ghost">View gym</.button>
            </div>
          </div>

          <.gym_header
            name="Bloc District"
            location="Madrid, Spain"
            members="1,284"
            active_routes="72"
          />
        </section>

        <section class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_block label="Sends this week" value="128" detail="+18% from last week" tone="lime" />
          <.stat_block label="Fresh problems" value="14" detail="Across 4 walls" tone="teal" />
          <.stat_block label="Most active grade" value="V4" detail="Community sweet spot" tone="clay" />
          <.stat_block label="New members" value="36" detail="Joined this month" tone="blue" />
        </section>

        <section class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <div class="space-y-4">
            <.header>
              Feed Components
              <:subtitle>Social-first cards with equal weight for media and conversation.</:subtitle>
            </.header>

            <.feed_item
              id="gallery-feed-ascent"
              author="Mara Silva"
              gym="Bloc District"
              time="12 min ago"
              grade="V5"
              body="Sent Blue Circuit #18 after a lot of heel-hook negotiations. The last move is all commitment."
              comments={9}
              reaction_count={42}
            />

            <.feed_item
              id="gallery-feed-text"
              author="Joel Chen"
              gym="North Cave"
              time="38 min ago"
              body="Anyone around for a mellow slab session tonight? I want to trade beta on the new yellow set."
              comments={4}
              reaction_count={17}
            />
          </div>

          <aside class="space-y-4">
            <.header>
              Route Cards
              <:subtitle>Bold grades should be scannable before the title.</:subtitle>
            </.header>

            <.route_card
              id="gallery-route-1"
              title="Static Fever"
              gym="Bloc District"
              grade="V5"
              status="Active"
              meta="Cave wall · blue tape · reset yesterday"
            />

            <.route_card
              id="gallery-route-2"
              title="Tiny Feet Club"
              gym="North Cave"
              grade="V7"
              status="Project"
              meta="Slab wall · pink tape · technical finish"
            />
          </aside>
        </section>

        <section class="grid gap-6 lg:grid-cols-2">
          <div class="rounded-lg border border-ascents-line bg-ascents-panel p-6">
            <.header>
              Form Components
              <:subtitle>
                Inputs keep the dark surface quiet while validation remains visible.
              </:subtitle>
            </.header>

            <.form for={@form} id="gallery-route-form">
              <.input field={@form[:name]} type="text" label="Route name" />
              <.input
                field={@form[:grade]}
                type="select"
                label="Grade"
                options={[V3: "V3", V4: "V4", V5: "V5", V6: "V6", V7: "V7"]}
              />
              <.input field={@form[:notes]} type="textarea" label="Setter notes" />
              <div class="flex flex-wrap gap-3">
                <.button>Save route</.button>
                <.button variant="secondary">Preview</.button>
              </div>
            </.form>
          </div>

          <div class="space-y-4">
            <.header>
              Empty and Feedback States
              <:subtitle>Friendly states should invite community action.</:subtitle>
            </.header>

            <.empty_state
              title="No sends here yet"
              description="Be the first climber to post beta, ask a question, or mark an ascent for this problem."
              icon="hero-sparkles"
            />

            <div class="grid gap-3 sm:grid-cols-2">
              <.grade_badge grade="V1" />
              <.grade_badge grade="V3" />
              <.grade_badge grade="V5" />
              <.grade_badge grade="V7" />
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp scope_from_token(nil), do: Scope.for_user(nil)

  defp scope_from_token(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> Scope.for_user(user)
      nil -> Scope.for_user(nil)
    end
  end
end
