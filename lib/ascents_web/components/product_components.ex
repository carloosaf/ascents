defmodule AscentsWeb.ProductComponents do
  @moduledoc """
  Ascents-specific UI components for social feed, gym, route, and stats surfaces.
  """
  use Phoenix.Component

  import AscentsWeb.CoreComponents

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
      class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line transition hover:-translate-y-1 hover:border-ascents-tape/70"
    >
      <div class="relative aspect-[4/3] bg-ascents-ink">
        <img :if={@image_url} src={@image_url} alt="" class="h-full w-full object-cover" />
        <div
          :if={!@image_url}
          class="route-hold-field relative flex h-full items-center justify-center overflow-hidden"
        >
          <span class="hold left-[18%] top-[22%] size-8 rotate-[-18deg] bg-ascents-tape"></span>
          <span class="hold right-[18%] top-[18%] size-11 rotate-[24deg] bg-grade-blue"></span>
          <span class="hold bottom-[22%] left-[32%] size-10 rotate-[12deg] bg-grade-pink"></span>
          <span class="hold bottom-[28%] right-[24%] size-7 rotate-[-28deg] bg-grade-yellow"></span>
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
      <div class="space-y-3 p-4">
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
      class="chalk-panel relative rounded-lg border border-ascents-line p-4 transition hover:border-ascents-action/55"
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
      class="chalk-panel relative rounded-lg border border-ascents-line p-4"
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

  def empty_state(assigns) do
    ~H"""
    <section
      data-component="empty-state"
      class="rounded-lg border border-dashed border-ascents-line bg-ascents-panel-deep/80 p-8 text-center"
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

  defp stat_tone_class("lime"), do: "text-ascents-tape"
  defp stat_tone_class("clay"), do: "text-ascents-clay"
  defp stat_tone_class("blue"), do: "text-grade-blue"
  defp stat_tone_class(_tone), do: "text-ascents-action"

  defp status_key(status) do
    status
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
  end

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
