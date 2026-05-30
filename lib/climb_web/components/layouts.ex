defmodule ClimbWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ClimbWeb, :html

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
    <header class="sticky top-0 z-40 border-b border-climb-line/80 bg-climb-ink/90 backdrop-blur-xl">
      <nav
        id="app-navigation"
        class="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8"
        aria-label="Main navigation"
      >
        <.link navigate={~p"/"} class="group flex min-w-0 items-center gap-3">
          <span class="tape-label flex size-9 items-center justify-center bg-climb-tape text-climb-tape-content shadow-lg transition group-hover:scale-105">
            <.icon name="hero-bolt-solid" class="size-5" />
          </span>
          <span class="min-w-0">
            <span class="climb-display block text-base leading-none text-climb-chalk">Climb</span>
            <span class="block truncate text-xs text-climb-muted">spray wall social</span>
          </span>
        </.link>

        <div class="flex items-center gap-2 sm:gap-3">
          <.theme_toggle />

          <%= if @current_scope do %>
            <span class="hidden max-w-[14rem] truncate text-sm text-climb-muted md:block">
              {@current_scope.user.email}
            </span>
            <.link
              href={~p"/users/settings"}
              class="rounded-md px-3 py-2 text-sm font-semibold text-climb-chalk transition hover:bg-climb-panel hover:text-white"
            >
              Settings
            </.link>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="rounded-md border border-climb-line px-3 py-2 text-sm font-semibold text-climb-chalk transition hover:border-climb-clay hover:text-climb-clay"
            >
              Log out
            </.link>
          <% else %>
            <.link
              href={~p"/users/log-in"}
              class="rounded-md px-3 py-2 text-sm font-semibold text-climb-chalk transition hover:bg-climb-panel hover:text-white"
            >
              Log in
            </.link>
            <.link
              href={~p"/users/register"}
              class="rounded-md bg-climb-action px-3 py-2 text-sm font-bold text-climb-action-content shadow-lg transition hover:-translate-y-0.5 hover:bg-climb-action-hover"
            >
              Join
            </.link>
          <% end %>
        </div>
      </nav>
    </header>

    <main class="climb-wall min-h-[calc(100vh-4rem)] bg-climb-ink px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

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
    <div class="relative grid grid-cols-3 rounded-md border border-climb-line bg-climb-panel p-1">
      <div class="absolute inset-y-1 w-[calc((100%-0.5rem)/3)] rounded bg-climb-panel-hover transition-[left] left-1 [[data-theme=light]_&]:left-[calc(33.333%)] [[data-theme=dark]_&]:left-[calc(66.666%-0.25rem)]" />

      <button
        type="button"
        class="relative flex size-8 cursor-pointer items-center justify-center rounded text-climb-muted transition hover:text-climb-chalk"
        aria-label="Use system theme"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        type="button"
        class="relative flex size-8 cursor-pointer items-center justify-center rounded text-climb-muted transition hover:text-climb-chalk"
        aria-label="Use light theme"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        type="button"
        class="relative flex size-8 cursor-pointer items-center justify-center rounded text-climb-chalk transition hover:text-white"
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
