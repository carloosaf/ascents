defmodule AscentsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AscentsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div id="app-shell" class="min-h-screen bg-ascents-ink md:pl-64">
      <aside
        id="app-sidebar"
        class="fixed inset-y-0 left-0 z-40 hidden w-64 flex-col border-r border-ascents-line bg-ascents-ink px-4 py-5 md:flex"
        aria-label="Primary navigation"
      >
        <.link navigate={~p"/"} class="group mb-8 flex items-center gap-3 px-2">
          <span class="tape-label flex size-10 shrink-0 items-center justify-center bg-ascents-tape text-ascents-tape-content shadow-lg transition group-hover:scale-105">
            <.icon name="hero-bolt-solid" class="size-6" />
          </span>
          <span class="min-w-0">
            <span class="ascents-display block text-lg leading-none text-ascents-chalk">
              Ascents
            </span>
            <span class="block truncate text-xs text-ascents-muted">climbing community</span>
          </span>
        </.link>

        <nav class="space-y-1" aria-label="Main navigation">
          <.nav_item
            :if={@current_scope}
            href={~p"/feed"}
            icon="hero-home"
            label="Home"
          />
          <.nav_item
            :if={@current_scope}
            href={~p"/friends"}
            icon="hero-user-group"
            label="Friends"
          />
          <.nav_item href={~p"/gyms"} icon="hero-building-storefront" label="Gyms" />
          <.nav_item
            :if={@current_scope}
            href={~p"/users/stats"}
            icon="hero-chart-bar-square"
            label="Progress"
          />
        </nav>

        <div class="mt-auto space-y-3 border-t border-ascents-line pt-4">
          <%= if @current_scope do %>
            <div class="relative">
              <div class="flex items-center gap-1 rounded-lg p-1 transition hover:bg-ascents-panel">
                <.link
                  id="sidebar-profile-link"
                  href={~p"/u/#{@current_scope.user.username}"}
                  class="group flex min-w-0 flex-1 items-center gap-3 rounded-md p-1"
                >
                  <.profile_picture user={@current_scope.user} size="md" />
                  <span class="min-w-0">
                    <span class="block truncate text-sm font-bold text-ascents-chalk">
                      {display_name(@current_scope.user)}
                    </span>
                    <span class="block truncate text-xs text-ascents-muted">
                      @{@current_scope.user.username}
                    </span>
                  </span>
                </.link>
                <button
                  id="sidebar-account-menu-button"
                  type="button"
                  class="flex size-9 shrink-0 items-center justify-center rounded-md text-ascents-muted transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
                  aria-label="Open account menu"
                  aria-controls="sidebar-account-menu"
                  phx-click={
                    JS.toggle(
                      to: "#sidebar-account-menu",
                      time: 180,
                      in:
                        {"transition ease-out duration-200", "opacity-0 translate-y-1 scale-95",
                         "opacity-100 translate-y-0 scale-100"},
                      out:
                        {"transition ease-in duration-150", "opacity-100 translate-y-0 scale-100",
                         "opacity-0 translate-y-1 scale-95"}
                    )
                  }
                >
                  <.icon name="hero-chevron-up" class="size-5" />
                </button>
              </div>

              <div
                id="sidebar-account-menu"
                class="ascents-menu chalk-panel absolute inset-x-0 bottom-full z-50 mb-2 hidden rounded-lg border border-ascents-line p-2 shadow-2xl shadow-black/40"
              >
                <.link
                  href={~p"/users/settings"}
                  class="flex items-center gap-3 rounded-md px-3 py-2.5 text-sm font-bold text-ascents-chalk transition hover:bg-ascents-panel-hover"
                >
                  <.icon name="hero-cog-6-tooth" class="size-5 text-ascents-muted" /> Settings
                </.link>
                <.link
                  href={~p"/users/log-out"}
                  method="delete"
                  class="flex items-center gap-3 rounded-md px-3 py-2.5 text-sm font-bold text-ascents-chalk transition hover:bg-ascents-panel-hover hover:text-ascents-clay"
                >
                  <.icon name="hero-arrow-left-on-rectangle" class="size-5 text-ascents-muted" />
                  Log out
                </.link>
              </div>
            </div>
          <% else %>
            <.link
              href={~p"/users/log-in"}
              class="flex min-h-11 items-center justify-center rounded-lg border border-ascents-line px-4 py-3 text-sm font-bold text-ascents-chalk transition hover:bg-ascents-panel"
            >
              Log in
            </.link>
            <.link
              href={~p"/users/register"}
              class="flex min-h-11 items-center justify-center rounded-lg bg-ascents-action px-4 py-3 text-sm font-black text-ascents-action-content shadow-lg transition hover:-translate-y-0.5 hover:bg-ascents-action-hover"
            >
              Join Ascents
            </.link>
          <% end %>
        </div>
      </aside>

      <header class="sticky top-0 z-30 border-b border-ascents-line/80 bg-ascents-ink/95 px-4 py-3 backdrop-blur-xl md:hidden">
        <.link navigate={~p"/"} class="inline-flex items-center gap-3">
          <span class="tape-label flex size-9 items-center justify-center bg-ascents-tape text-ascents-tape-content shadow-lg">
            <.icon name="hero-bolt-solid" class="size-5" />
          </span>
          <span class="ascents-display text-base leading-none text-ascents-chalk">Ascents</span>
        </.link>
      </header>

      <main class="ascents-wall min-h-screen bg-ascents-ink px-4 py-6 pb-28 sm:px-6 md:px-8 md:py-10">
        <div class="mx-auto max-w-7xl">
          {render_slot(@inner_block)}
        </div>
      </main>

      <nav
        id="app-mobile-tabbar"
        class="fixed inset-x-0 bottom-0 z-40 border-t border-ascents-line bg-ascents-ink/95 px-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 backdrop-blur-xl md:hidden"
        aria-label="Primary navigation"
      >
        <div class={[
          "mx-auto grid max-w-lg gap-1",
          if(@current_scope, do: "grid-cols-5", else: "grid-cols-4")
        ]}>
          <%= if @current_scope do %>
            <.mobile_nav_item href={~p"/feed"} icon="hero-home" label="Home" />
            <.mobile_nav_item href={~p"/friends"} icon="hero-user-group" label="Friends" />
            <.mobile_nav_item href={~p"/gyms"} icon="hero-building-storefront" label="Gyms" />
            <.mobile_nav_item href={~p"/users/stats"} icon="hero-chart-bar-square" label="Progress" />
            <.link
              id="mobile-profile-link"
              href={~p"/u/#{@current_scope.user.username}"}
              class="flex min-h-14 flex-col items-center justify-center gap-1 rounded-lg px-2 text-[0.68rem] font-bold text-ascents-muted transition hover:bg-ascents-panel hover:text-ascents-chalk"
            >
              <.profile_picture user={@current_scope.user} size="sm" /> Profile
            </.link>
          <% else %>
            <.mobile_nav_item href={~p"/"} icon="hero-home" label="Start" />
            <.mobile_nav_item href={~p"/gyms"} icon="hero-building-storefront" label="Gyms" />
            <.mobile_nav_item
              href={~p"/users/log-in"}
              icon="hero-arrow-right-on-rectangle"
              label="Log in"
            />
            <.mobile_nav_item href={~p"/users/register"} icon="hero-user-plus" label="Join" />
          <% end %>
        </div>
      </nav>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  def nav_item(assigns) do
    ~H"""
    <.link
      href={@href}
      class="flex items-center gap-3 rounded-lg px-3 py-3 text-base font-black text-ascents-chalk transition hover:bg-ascents-panel hover:text-white"
    >
      <.icon name={@icon} class="size-6 text-ascents-muted" />
      {@label}
    </.link>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  def mobile_nav_item(assigns) do
    ~H"""
    <.link
      href={@href}
      class="flex min-h-14 flex-col items-center justify-center gap-1 rounded-lg px-2 text-[0.68rem] font-bold text-ascents-muted transition hover:bg-ascents-panel hover:text-ascents-chalk"
    >
      <.icon name={@icon} class="size-5" />
      {@label}
    </.link>
    """
  end

  defp display_name(user) do
    user.display_name || user.username || user.email
  end

  defp theme_preference(%{user: %{theme_preference: theme_preference}}), do: theme_preference
  defp theme_preference(_scope), do: nil

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative grid grid-cols-3 rounded-md border border-ascents-line bg-ascents-panel p-1">
      <div class="absolute inset-y-1 w-[calc((100%-0.5rem)/3)] rounded bg-ascents-panel-hover transition-[left] left-1 [[data-theme=light]_&]:left-[calc(33.333%)] [[data-theme=dark]_&]:left-[calc(66.666%-0.25rem)]" />

      <button
        type="button"
        class="relative flex size-8 cursor-pointer items-center justify-center rounded text-ascents-muted transition hover:text-ascents-chalk"
        aria-label="Use system theme"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        type="button"
        class="relative flex size-8 cursor-pointer items-center justify-center rounded text-ascents-muted transition hover:text-ascents-chalk"
        aria-label="Use light theme"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        type="button"
        class="relative flex size-8 cursor-pointer items-center justify-center rounded text-ascents-chalk transition hover:text-white"
        aria-label="Use dark theme"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
