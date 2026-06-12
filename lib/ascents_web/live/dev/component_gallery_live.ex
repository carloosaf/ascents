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

        <section class="space-y-4">
          <.header>
            Ascent Feed Treatment
            <:subtitle>
              The selected ascent treatment shown as a normal feed post, with and without
              media, so spacing stays comparable to regular posts.
            </:subtitle>
          </.header>

          <div class="mx-auto max-w-3xl space-y-5">
            <div class="space-y-3">
              <div class="flex items-center justify-between gap-3">
                <h2 class="text-sm font-black uppercase text-ascents-chalk">
                  Reference · Normal Post
                </h2>
                <span class="rounded-md bg-ascents-panel-hover px-2 py-1 text-xs font-bold text-ascents-muted">
                  Baseline
                </span>
              </div>
              <.feed_item
                id="gallery-ascent-context-normal"
                author="Joel Chen"
                gym="Bloc District"
                time="9 min ago"
                body="Anyone working the cave set tonight? I want to trade beta on the blue compression problem."
                comments={4}
                reaction_count={18}
              />
            </div>

            <.gallery_ascent_route_send_post id="gallery-ascent-route-send-post" />
            <.gallery_ascent_route_send_post
              id="gallery-ascent-route-send-post-with-image"
              image_url={~p"/images/gallery-ascent-post.png"}
              label="Chosen · With Image"
              tone="Image check"
            />
          </div>
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

  attr :label, :string, required: true
  attr :tone, :string, required: true

  defp concept_label(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3">
      <h2 class="text-sm font-black uppercase text-ascents-chalk">{@label}</h2>
      <span class="rounded-md bg-ascents-panel-hover px-2 py-1 text-xs font-bold text-ascents-muted">
        {@tone}
      </span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :image_url, :string, default: nil
  attr :label, :string, default: "Chosen · Ascent Post"
  attr :tone, :string, default: "Visual"

  defp gallery_ascent_route_send_post(assigns) do
    ~H"""
    <div class="space-y-3">
      <.concept_label label={@label} tone={@tone} />
      <article id={@id} class="chalk-panel relative rounded-lg border border-ascents-line p-4">
        <div class="flex items-start gap-3">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-md bg-ascents-tape text-sm font-black text-ascents-tape-content tape-label">
            MS
          </div>
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
              <h3 class="font-bold text-ascents-chalk">Mara Silva</h3>
              <span class="text-sm text-ascents-muted">sent</span>
              <span class="text-sm font-semibold text-ascents-tape">Compression Line</span>
              <span class="text-sm text-ascents-muted">in Bloc District</span>
              <span class="text-xs text-ascents-muted-strong">12 min ago</span>
            </div>
          </div>
          <.grade_badge grade="V5" />
        </div>

        <div class="mt-2 flex flex-wrap items-center gap-2 text-xs font-black uppercase text-ascents-muted">
          <span class="inline-flex items-center gap-1 text-ascents-tape">
            <.icon name="hero-check-badge" class="size-4" /> Ascent
          </span>
          <span>/</span>
          <span class="inline-flex items-center gap-1">
            <span class="size-2 rounded-full bg-grade-blue"></span>
            Blue holds
          </span>
          <span>/</span>
          <span>Cave wall</span>
          <span>/</span>
          <span>Jun 11 · 10:30</span>
        </div>

        <p class="mt-2 text-sm leading-6 text-ascents-chalk-soft">
          Sent after three careful burns. The final bump felt much easier once the left heel stayed high.
        </p>

        <div
          :if={@image_url}
          class="mt-4 overflow-hidden rounded-lg border border-ascents-line bg-ascents-panel-deep"
        >
          <img src={@image_url} alt="" class="aspect-video w-full object-cover" />
        </div>

        <.gallery_post_actions />
      </article>
    </div>
    """
  end

  defp gallery_post_actions(assigns) do
    ~H"""
      <div class="relative z-10 mt-4 flex flex-wrap items-center gap-2 border-t border-ascents-line pt-3 text-sm text-ascents-muted">
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-md px-2 py-1 transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
        >
          <.icon name="hero-sparkles" class="size-4 text-ascents-tape" /> 42
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-md px-2 py-1 transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
        >
          <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> 9
        </button>
      </div>
    """
  end
end
