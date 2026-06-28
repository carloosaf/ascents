defmodule AscentsWeb.ProductComponents do
  @moduledoc """
  Ascents-specific UI components for social feed, gym, route, and stats surfaces.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: AscentsWeb.Endpoint,
    router: AscentsWeb.Router,
    statics: AscentsWeb.static_paths()

  import AscentsWeb.CoreComponents

  alias Ascents.Feed
  alias Ascents.Media

  attr :upload, :map, required: true
  attr :label, :string, required: true
  attr :help, :string, default: "JPG, PNG, or WebP up to 5 MB."
  attr :id, :string, default: nil
  attr :capture, :string, default: nil

  def image_upload_input(assigns) do
    ~H"""
    <div id={@id} class="mb-4">
      <label for={@upload.ref} class="block">
        <span class="mb-1.5 block text-sm font-semibold text-ascents-chalk">
          {@label}
        </span>
        <.live_file_input
          upload={@upload}
          capture={@capture}
          class="block w-full rounded-md border border-ascents-line bg-ascents-panel-deep px-3 py-2.5 text-sm text-ascents-chalk file:mr-3 file:rounded-md file:border-0 file:bg-ascents-action file:px-3 file:py-1.5 file:text-sm file:font-bold file:text-ascents-action-content hover:file:bg-ascents-action-hover"
        />
      </label>
      <p class="mt-1.5 text-xs text-ascents-muted">
        {@help}
      </p>
      <p
        :for={entry <- @upload.entries}
        class="mt-2 text-xs font-bold text-ascents-action"
      >
        <span class="flex items-center justify-between gap-3">
          <span class="truncate">Uploading {entry.client_name}</span>
          <span>{entry.progress}%</span>
        </span>
        <span class="mt-1 block h-1.5 overflow-hidden rounded-full bg-ascents-panel-deep">
          <span
            class="ascents-upload-progress block h-full rounded-full transition-[width] duration-200 ease-out"
            style={"width: #{entry.progress}%"}
          >
          </span>
        </span>
      </p>
      <p
        :for={err <- upload_errors(@upload)}
        class="mt-1.5 text-sm text-ascents-danger-hover"
      >
        {Media.upload_error_message(err)}
      </p>
    </div>
    """
  end

  attr :user, :map, required: true
  attr :size, :string, default: "md", values: ~w(sm md lg xl)
  attr :id, :string, default: nil
  attr :class, :any, default: nil

  def profile_picture(assigns) do
    assigns =
      assigns
      |> assign(:name, profile_name(assigns.user))
      |> assign(:avatar_url, Media.signed_url(assigns.user.avatar_object_key))
      |> assign(:size_class, profile_picture_size(assigns.size))

    ~H"""
    <span
      id={@id}
      data-component="profile-picture"
      class={["relative inline-flex shrink-0 overflow-hidden rounded-md", @size_class, @class]}
    >
      <img
        :if={@avatar_url}
        src={@avatar_url}
        alt={"#{@name} avatar"}
        class="h-full w-full object-cover"
      />
      <span
        :if={!@avatar_url}
        class="tape-label flex h-full w-full items-center justify-center bg-ascents-tape font-black text-ascents-tape-content"
      >
        {initials(@name)}
      </span>
    </span>
    """
  end

  attr :id, :string, required: true
  attr :gym, :map, required: true

  def gym_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={~p"/gyms/#{@gym.slug}"}
      class="ascents-reveal chalk-panel group relative flex flex-col overflow-hidden rounded-lg border border-ascents-line p-4 transition hover:-translate-y-1 hover:border-ascents-action/60"
    >
      <div class="relative mb-5 aspect-square overflow-hidden rounded-md border border-ascents-line bg-ascents-panel-deep">
        <img
          :if={@gym.image_object_key}
          src={Media.signed_url(@gym.image_object_key)}
          alt=""
          class="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
        />
        <div
          :if={!@gym.image_object_key}
          class="route-hold-field relative flex h-full items-center justify-center overflow-hidden"
        >
          <span class="hold left-[18%] top-[18%] size-9 rotate-[-18deg] bg-ascents-tape"></span>
          <span class="hold right-[16%] top-[24%] size-12 rotate-[24deg] bg-grade-blue"></span>
          <span class="hold bottom-[18%] left-[28%] size-11 rotate-[12deg] bg-grade-pink"></span>
          <span class="route-title-plate relative z-10 rounded-md px-4 py-3 text-2xl font-black uppercase text-ascents-route-title backdrop-blur">
            {initials(@gym.name)}
          </span>
        </div>
      </div>

      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <p class="text-xs font-bold uppercase text-ascents-route-subtitle">
            {@gym.location || "Location TBD"}
          </p>
          <h2 class="mt-2 truncate text-xl font-black text-ascents-chalk">
            {@gym.name}
          </h2>
        </div>
        <span class="shrink-0 rounded-md border border-ascents-line bg-ascents-panel-deep px-2.5 py-1 text-xs font-bold text-ascents-muted">
          {grade_scale_label(@gym.grade_scale)}
        </span>
      </div>
      <p class="mt-4 line-clamp-3 flex-1 text-sm leading-6 text-ascents-chalk-soft">
        {@gym.description || "No description yet."}
      </p>
      <p class="mt-5 inline-flex items-center gap-2 text-sm font-bold text-ascents-action transition group-hover:text-ascents-action-hover">
        Open community <.icon name="hero-arrow-right" class="size-4" />
      </p>
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :problem, :map, required: true
  attr :gym, :map, required: true

  def route_admin_card(assigns) do
    ~H"""
    <article
      id={@id}
      class="ascents-stream-item chalk-panel relative grid overflow-hidden rounded-lg border border-ascents-line sm:grid-cols-[10rem_minmax(0,1fr)]"
    >
      <div class="route-hold-field relative aspect-[3/4] overflow-hidden border-b border-ascents-line bg-ascents-panel-deep sm:aspect-auto sm:h-full sm:min-h-64 sm:border-b-0 sm:border-r">
        <img
          :if={@problem.image_object_key}
          src={Media.signed_url(@problem.image_object_key)}
          alt=""
          class="h-full w-full object-cover"
        />
        <div
          :if={!@problem.image_object_key}
          class="relative flex h-full items-center justify-center overflow-hidden"
        >
          <span class="hold left-[24%] top-[14%] size-8 rotate-[-18deg] bg-ascents-tape"></span>
          <span class="hold right-[18%] top-[34%] size-10 rotate-[24deg] bg-grade-blue"></span>
          <span class="hold bottom-[22%] left-[32%] size-9 rotate-[12deg] bg-grade-pink"></span>
          <span class="hold bottom-[12%] right-[24%] size-7 rotate-[-28deg] bg-grade-yellow"></span>
          <div class="route-title-plate relative z-10 rounded-md px-3 py-2 text-xs font-black uppercase text-ascents-route-title backdrop-blur">
            route photo
          </div>
        </div>
        <div class="absolute left-3 top-3">
          <.grade_badge grade={@problem.grade} />
        </div>
      </div>

      <div class="flex min-w-0 flex-col p-4">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <h2 class="text-lg font-black text-ascents-chalk">{@problem.title}</h2>
            <p class="mt-1 text-sm text-ascents-muted">{@problem.color}</p>
          </div>
          <span class={[
            "shrink-0 rounded-md px-2.5 py-1 text-xs font-black uppercase",
            @problem.active && "bg-ascents-tape text-ascents-tape-content",
            !@problem.active && "bg-ascents-panel-hover text-ascents-muted"
          ]}>
            {if(@problem.active, do: "Active", else: "Archived")}
          </span>
        </div>

        <p class="mt-4 min-h-12 flex-1 text-sm leading-6 text-ascents-chalk-soft">
          {@problem.description || "No route notes yet."}
        </p>

        <div class="mt-4 flex flex-wrap gap-2">
          <.button
            id={"problem-edit-link-#{@problem.id}"}
            navigate={~p"/gyms/#{@gym.slug}/problems/#{@problem.id}/edit"}
            variant="secondary"
          >
            <.icon name="hero-pencil-square" class="size-4" /> Edit
          </.button>
          <.button
            :if={@problem.active}
            id={"problem-archive-button-#{@problem.id}"}
            phx-click="archive"
            phx-value-id={@problem.id}
            variant="danger"
          >
            <.icon name="hero-archive-box" class="size-4" /> Archive
          </.button>
          <.button
            :if={!@problem.active}
            id={"problem-reactivate-button-#{@problem.id}"}
            phx-click="reactivate"
            phx-value-id={@problem.id}
            variant="secondary"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Reactivate
          </.button>
        </div>
      </div>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :post, :map, required: true
  attr :current_scope, :map, required: true
  attr :comment_form, Phoenix.HTML.Form, required: true
  attr :show_gym?, :boolean, default: true
  attr :show_owner_actions, :boolean, default: true

  def feed_post(assigns) do
    assigns =
      assign(
        assigns,
        :post_image_url,
        Media.signed_url(assigns.current_scope, {:post, assigns.post})
      )

    ~H"""
    <article
      id={@id}
      class="ascents-stream-item chalk-panel relative rounded-lg border border-ascents-line p-4"
    >
      <button
        :if={@show_owner_actions && Feed.can_delete_post?(@current_scope, @post.gym, @post)}
        id={"home-post-delete-#{@post.id}"}
        type="button"
        phx-click="delete-post"
        phx-value-id={@post.id}
        class="absolute right-3 top-3 rounded-md border border-transparent p-2 text-ascents-muted-strong opacity-70 transition hover:border-ascents-danger/30 hover:bg-ascents-danger/10 hover:text-ascents-danger-hover hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ascents-danger/40 focus:ring-offset-2 focus:ring-offset-ascents-panel"
        aria-label="Delete post"
      >
        <.icon name="hero-trash" class="size-4" />
      </button>

      <div class="flex items-start gap-3">
        <.profile_picture user={@post.user} />
        <div class="min-w-0 flex-1 pr-10">
          <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
            <.link
              navigate={~p"/u/#{@post.user.username}"}
              class="font-bold text-ascents-chalk hover:text-white"
            >
              {profile_name(@post.user)}
            </.link>
            <span :if={ascent_post?(@post)} class="text-sm text-ascents-muted">sent</span>
            <span :if={!ascent_post?(@post) && @show_gym?} class="text-sm text-ascents-muted">
              in
            </span>
            <span :if={ascent_post?(@post)} class="text-sm font-semibold text-ascents-tape">
              {route_title(@post)}
            </span>
            <span :if={ascent_post?(@post) && @show_gym?} class="text-sm text-ascents-muted">in</span>
            <.link
              :if={@show_gym?}
              navigate={~p"/gyms/#{@post.gym.slug}"}
              class="text-sm font-semibold text-ascents-tape hover:text-ascents-tape-hover"
            >
              {@post.gym.name}
            </.link>
            <span class="text-xs text-ascents-muted-strong">{format_time(@post.inserted_at)}</span>
          </div>
        </div>
      </div>

      <div
        :if={ascent_post?(@post)}
        id={"home-post-ascent-#{@post.id}"}
        class="mt-3 flex flex-wrap items-center gap-2 text-xs font-black uppercase text-ascents-muted"
      >
        <span class="inline-flex items-center gap-1 text-ascents-tape">
          <.icon name="hero-check-badge" class="size-4" /> Ascent
        </span>
        <span>/</span>
        <.grade_badge grade={ascent_grade(@post)} />
        <span>/</span>
        <span :if={route_hold_color(@post)} class="inline-flex items-center gap-1">
          <span class={["size-2 rounded-full", hold_color_class(route_hold_color(@post))]}></span>
          {route_hold_color(@post)} holds
        </span>
        <span :if={route_hold_color(@post)}>/</span>
        <span>{format_ascent_time(@post.ascent)}</span>
      </div>

      <p
        :if={@post.body}
        class={[
          "whitespace-pre-line text-sm leading-6 text-ascents-chalk-soft",
          if(ascent_post?(@post), do: "mt-2", else: "mt-3")
        ]}
      >
        {@post.body}
      </p>

      <div
        :if={@post_image_url}
        class="mt-3 overflow-hidden rounded-lg border border-ascents-line"
      >
        <img
          id={"home-post-image-#{@post.id}"}
          src={@post_image_url}
          alt=""
          class="aspect-video w-full object-cover"
        />
      </div>

      <section class="mt-4 space-y-3 border-t border-ascents-line pt-4">
        <div id={"home-post-comments-#{@post.id}"} class="space-y-2">
          <div
            :for={comment <- @post.comments}
            :if={is_nil(comment.deleted_at)}
            id={"home-comment-#{comment.id}"}
            class="rounded-md bg-ascents-panel-deep px-3 py-2 text-sm"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex min-w-0 items-start gap-2">
                <.profile_picture user={comment.user} size="sm" />
                <p class="min-w-0 text-ascents-chalk-soft">
                  <span class="font-bold text-ascents-chalk">{profile_name(comment.user)}</span>
                  {comment.body}
                </p>
              </div>
              <button
                :if={
                  @show_owner_actions &&
                    Feed.can_delete_comment?(@current_scope, @post.gym, @post, comment)
                }
                id={"home-comment-delete-#{comment.id}"}
                type="button"
                phx-click="delete-comment"
                phx-value-post_id={@post.id}
                phx-value-id={comment.id}
                class="rounded p-1 text-ascents-muted transition hover:text-ascents-danger-hover"
                aria-label="Delete comment"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
          </div>
        </div>

        <.form
          for={@comment_form}
          id={"home-comment-form-#{@post.id}"}
          phx-submit="comment"
          class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end"
        >
          <input type="hidden" name="post_id" value={@post.id} />
          <.input
            field={@comment_form[:body]}
            type="text"
            label="Comment"
            placeholder="Add a comment"
            class="min-h-10 w-full rounded-md border border-ascents-line bg-ascents-panel-deep px-3 py-2.5 text-sm text-ascents-chalk outline-none transition placeholder:text-ascents-muted-strong focus:border-ascents-action focus:ring-2 focus:ring-ascents-action/20 disabled:cursor-not-allowed disabled:opacity-60"
          />
          <button
            type="submit"
            class="mb-4 flex size-10 shrink-0 items-center justify-center rounded-md bg-ascents-action text-ascents-action-content shadow-lg transition duration-150 ease-out hover:-translate-y-0.5 hover:bg-ascents-action-hover focus:outline-none focus:ring-2 focus:ring-ascents-tape/70 focus:ring-offset-2 focus:ring-offset-ascents-ink disabled:pointer-events-none disabled:opacity-50"
            phx-disable-with="Posting..."
            aria-label="Post comment"
          >
            <.icon name="hero-paper-airplane" class="size-5" />
          </button>
        </.form>
      </section>
    </article>
    """
  end

  attr :grade, :string, required: true
  attr :label, :string, default: nil
  attr :rest, :global

  def grade_badge(assigns) do
    assigns = assign(assigns, :grade_class, grade_class(assigns.grade))

    ~H"""
    <span
      data-component="grade-badge"
      class={[
        "tape-label inline-flex items-center gap-1 px-3 py-1 text-xs font-black uppercase tracking-normal",
        @grade_class
      ]}
      {@rest}
    >
      <span class="size-1.5 rounded-full bg-current opacity-70"></span>
      {@label || @grade}
    </span>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :gym, :string, required: true
  attr :grade, :string, required: true
  attr :status, :string, default: "Active"
  attr :meta, :string, default: nil
  attr :image_url, :string, default: nil

  def route_card(assigns) do
    ~H"""
    <article
      id={@id}
      data-component="route-card"
      class="ascents-reveal chalk-panel relative grid overflow-hidden rounded-lg border border-ascents-line transition hover:-translate-y-1 hover:border-ascents-tape/70 sm:grid-cols-[minmax(8rem,38%)_minmax(0,1fr)]"
    >
      <div class="route-hold-field relative aspect-[3/4] overflow-hidden border-b border-ascents-line bg-ascents-ink sm:aspect-auto sm:h-full sm:min-h-64 sm:border-b-0 sm:border-r">
        <img :if={@image_url} src={@image_url} alt="" class="h-full w-full object-cover" />
        <div
          :if={!@image_url}
          class="relative flex h-full items-center justify-center overflow-hidden"
        >
          <span class="hold left-[24%] top-[14%] size-8 rotate-[-18deg] bg-ascents-tape"></span>
          <span class="hold right-[18%] top-[34%] size-10 rotate-[24deg] bg-grade-blue"></span>
          <span class="hold bottom-[22%] left-[32%] size-9 rotate-[12deg] bg-grade-pink"></span>
          <span class="hold bottom-[12%] right-[24%] size-7 rotate-[-28deg] bg-grade-yellow"></span>
          <div class="route-title-plate relative z-10 rounded-md px-3 py-2 text-xs font-black uppercase text-ascents-route-title backdrop-blur">
            route photo
          </div>
        </div>
        <div class="absolute left-3 top-3">
          <.grade_badge grade={@grade} />
        </div>
        <span
          class="route-status-badge absolute bottom-3 right-3 rounded-md px-2.5 py-1 text-xs font-black uppercase backdrop-blur"
          data-status={status_key(@status)}
        >
          {@status}
        </span>
      </div>
      <div class="flex min-w-0 flex-col space-y-3 p-4">
        <div>
          <h3 class="text-base font-bold leading-6 text-ascents-chalk">{@title}</h3>
          <p class="mt-1 text-sm text-ascents-muted">{@gym}</p>
        </div>
        <p :if={@meta} class="text-sm text-ascents-chalk-soft">{@meta}</p>
      </div>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :author, :string, required: true
  attr :gym, :string, required: true
  attr :time, :string, required: true
  attr :body, :string, required: true
  attr :grade, :string, default: nil
  attr :image_url, :string, default: nil
  attr :comments, :integer, default: 0
  attr :reaction_count, :integer, default: 0

  def feed_item(assigns) do
    ~H"""
    <article
      id={@id}
      data-component="feed-item"
      class="ascents-reveal chalk-panel relative rounded-lg border border-ascents-line p-4 transition hover:border-ascents-action/55"
    >
      <div class="relative z-10 flex items-start gap-3">
        <div class="flex size-10 shrink-0 items-center justify-center rounded-md bg-ascents-tape text-sm font-black text-ascents-tape-content tape-label">
          {initials(@author)}
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
            <h3 class="font-bold text-ascents-chalk">{@author}</h3>
            <span class="text-sm text-ascents-muted">posted in {@gym}</span>
            <span class="text-xs text-ascents-muted-strong">{@time}</span>
          </div>
          <p class="mt-3 text-sm leading-6 text-ascents-chalk-soft">{@body}</p>
        </div>
        <.grade_badge :if={@grade} grade={@grade} />
      </div>

      <div
        :if={@image_url}
        class="relative z-10 mt-4 overflow-hidden rounded-lg border border-ascents-line"
      >
        <img src={@image_url} alt="" class="aspect-video w-full object-cover" />
      </div>

      <div class="relative z-10 mt-4 flex flex-wrap items-center gap-2 text-sm text-ascents-muted">
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-md px-2 py-1 transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
        >
          <.icon name="hero-sparkles" class="size-4 text-ascents-tape" /> {@reaction_count}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-md px-2 py-1 transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
        >
          <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> {@comments}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-md px-2 py-1 transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
        >
          <.icon name="hero-arrow-up-tray" class="size-4" /> Share
        </button>
      </div>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, default: nil
  attr :tone, :string, default: "teal", values: ~w(teal lime clay blue)

  def stat_block(assigns) do
    assigns = assign(assigns, :tone_class, stat_tone_class(assigns.tone))

    ~H"""
    <section
      data-component="stat-block"
      class="ascents-reveal chalk-panel relative rounded-lg border border-ascents-line p-4"
    >
      <p class="relative z-10 text-sm font-semibold text-ascents-muted">{@label}</p>
      <p class={["ascents-display relative z-10 mt-2 text-4xl", @tone_class]}>{@value}</p>
      <p :if={@detail} class="relative z-10 mt-2 text-sm text-ascents-chalk-soft">{@detail}</p>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, default: "hero-face-smile"
  attr :rest, :global

  def empty_state(assigns) do
    ~H"""
    <section
      data-component="empty-state"
      class="ascents-reveal rounded-lg border border-dashed border-ascents-line bg-ascents-panel-deep/80 p-8 text-center"
      {@rest}
    >
      <div class="mx-auto flex size-12 items-center justify-center rounded-lg bg-ascents-panel-hover text-ascents-tape">
        <.icon name={@icon} class="size-6" />
      </div>
      <h3 class="mt-4 text-lg font-bold text-ascents-chalk">{@title}</h3>
      <p class="mx-auto mt-2 max-w-md text-sm leading-6 text-ascents-muted">{@description}</p>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :location, :string, required: true
  attr :members, :string, required: true
  attr :active_routes, :string, required: true
  attr :image_url, :string, default: nil

  def gym_header(assigns) do
    ~H"""
    <section
      data-component="gym-header"
      class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line"
    >
      <div class="route-hold-field relative min-h-64 overflow-hidden p-6 sm:p-8">
        <img
          :if={@image_url}
          src={@image_url}
          alt=""
          class="absolute inset-0 h-full w-full object-cover opacity-70"
        />
        <div :if={@image_url} class="absolute inset-0 bg-ascents-ink/45"></div>
        <span
          :if={!@image_url}
          class="hold right-[14%] top-[18%] size-10 rotate-[24deg] bg-grade-blue opacity-85"
        >
        </span>
        <span
          :if={!@image_url}
          class="hold right-[34%] bottom-[18%] size-8 rotate-[-16deg] bg-grade-pink opacity-85"
        >
        </span>
        <div class="route-title-plate relative z-10 max-w-2xl rounded-lg px-4 py-3 backdrop-blur">
          <p class="text-sm font-bold uppercase text-ascents-route-subtitle">{@location}</p>
          <h1 class="ascents-display mt-3 text-4xl leading-none text-ascents-route-title sm:text-5xl">
            {@name}
          </h1>
        </div>
      </div>
      <div class="grid gap-px bg-ascents-line sm:grid-cols-2">
        <div class="bg-ascents-panel p-4">
          <p class="text-sm text-ascents-muted">Members</p>
          <p class="mt-1 text-2xl font-black text-ascents-chalk">{@members}</p>
        </div>
        <div class="bg-ascents-panel p-4">
          <p class="text-sm text-ascents-muted">Active routes</p>
          <p class="mt-1 text-2xl font-black text-ascents-tape">{@active_routes}</p>
        </div>
      </div>
    </section>
    """
  end

  defp grade_class(grade) do
    cond do
      grade in ["V0", "V1", "4", "5"] -> "bg-grade-blue text-grade-blue-content"
      grade in ["V2", "V3", "6A", "6A+"] -> "bg-grade-purple text-grade-purple-content"
      grade in ["V4", "V5", "6B", "6B+"] -> "bg-grade-pink text-grade-pink-content"
      grade in ["V6", "V7", "6C", "6C+"] -> "bg-grade-yellow text-grade-yellow-content"
      true -> "bg-ascents-danger-hover text-grade-red-content"
    end
  end

  defp hold_color_class(color) do
    case String.downcase(to_string(color)) do
      "blue" -> "bg-grade-blue text-grade-blue-content"
      "purple" -> "bg-grade-purple text-grade-purple-content"
      "pink" -> "bg-grade-pink text-grade-pink-content"
      "yellow" -> "bg-grade-yellow text-grade-yellow-content"
      "red" -> "bg-grade-red text-grade-red-content"
      _color -> "bg-ascents-tape text-ascents-tape-content"
    end
  end

  defp grade_scale_label("french"), do: "French bouldering"
  defp grade_scale_label(_grade_scale), do: "V scale"

  defp stat_tone_class("lime"), do: "text-ascents-tape"
  defp stat_tone_class("clay"), do: "text-ascents-clay"
  defp stat_tone_class("blue"), do: "text-grade-blue"
  defp stat_tone_class(_tone), do: "text-ascents-action"

  defp status_key(status) do
    status
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
  end

  defp profile_picture_size("sm"), do: "size-7 text-xs"
  defp profile_picture_size("lg"), do: "size-14 text-lg"
  defp profile_picture_size("xl"), do: "size-20 text-2xl"
  defp profile_picture_size(_size), do: "size-10 text-sm"

  defp profile_name(user), do: user.display_name || user.username

  defp format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%b %-d, %Y")
  defp format_time(_datetime), do: ""

  defp format_ascent_time(%{climbed_at: %DateTime{} = datetime}) do
    Calendar.strftime(datetime, "%b %-d, %Y at %H:%M")
  end

  defp format_ascent_time(_ascent), do: "Ascent date"

  defp ascent_post?(%{post_type: "ascent"}), do: true
  defp ascent_post?(_post), do: false

  defp route_title(%{boulder_problem: %{title: title}}) when is_binary(title), do: title
  defp route_title(_post), do: "Archived route"

  defp route_hold_color(%{boulder_problem: %{color: color}}) when is_binary(color) do
    case String.trim(color) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp route_hold_color(_post), do: nil

  defp ascent_grade(%{ascent: %{grade_snapshot: grade}}) when is_binary(grade), do: grade
  defp ascent_grade(%{boulder_problem: %{grade: grade}}) when is_binary(grade), do: grade
  defp ascent_grade(_post), do: "Route"

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
