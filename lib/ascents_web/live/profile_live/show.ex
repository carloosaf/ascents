defmodule AscentsWeb.ProfileLive.Show do
  use AscentsWeb, :live_view

  alias Ascents.Accounts
  alias Ascents.Accounts.Scope
  alias Ascents.Media

  def mount(%{"username" => username}, session, socket) do
    current_scope =
      session
      |> Map.get("user_token")
      |> scope_from_token()

    if current_scope do
      profile_user = Accounts.get_user_by_username!(username)

      {:ok,
       assign(socket,
         current_scope: current_scope,
         profile_user: profile_user,
         owner?: current_scope.user.id == profile_user.id,
         avatar_url: profile_avatar_url(current_scope, profile_user)
       )}
    else
      {:ok, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="profile-show" class="space-y-8">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line">
          <div class="route-hold-field relative overflow-hidden p-6 sm:p-8">
            <span class="hold right-[12%] top-[18%] size-10 rotate-[20deg] bg-ascents-tape opacity-90">
            </span>
            <span class="hold right-[28%] bottom-[16%] size-8 rotate-[-18deg] bg-grade-blue opacity-80">
            </span>

            <div class="relative z-10 flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
              <div class="flex min-w-0 items-center gap-4">
                <div
                  :if={!@avatar_url}
                  id="profile-avatar"
                  class="tape-label flex size-20 shrink-0 items-center justify-center bg-ascents-tape text-2xl font-black text-ascents-tape-content shadow-xl"
                >
                  {profile_initials(@profile_user)}
                </div>
                <img
                  :if={@avatar_url}
                  id="profile-avatar"
                  src={@avatar_url}
                  alt=""
                  class="size-20 shrink-0 rounded-md border border-ascents-line object-cover shadow-xl"
                />

                <div class="min-w-0">
                  <p class="text-sm font-bold uppercase text-ascents-route-subtitle">
                    /u/{@profile_user.username}
                  </p>
                  <h1
                    id="profile-display-name"
                    class="ascents-display mt-2 truncate text-4xl leading-none text-ascents-route-title sm:text-5xl"
                  >
                    {profile_name(@profile_user)}
                  </h1>
                </div>
              </div>

              <.link
                :if={@owner?}
                id="profile-edit-link"
                href={~p"/users/settings/profile"}
                class="inline-flex items-center justify-center rounded-md bg-ascents-action px-4 py-2 text-sm font-bold text-ascents-action-content shadow-lg transition hover:-translate-y-0.5 hover:bg-ascents-action-hover"
              >
                Edit profile
              </.link>
            </div>
          </div>

          <div class="border-t border-ascents-line bg-ascents-panel p-6">
            <p id="profile-bio" class="max-w-3xl text-sm leading-6 text-ascents-chalk-soft">
              {profile_bio(@profile_user)}
            </p>
          </div>
        </section>

        <section class="grid gap-4 sm:grid-cols-3">
          <.stat_block label="Sends" value="0" detail="No sends recorded" tone="lime" />
          <.stat_block label="Gyms" value="0" detail="No gym memberships yet" tone="teal" />
          <.stat_block label="Projects" value="0" detail="No active projects yet" tone="blue" />
        </section>

        <.empty_state
          title="No climbing activity yet"
          description="Gym activity, ascent posts, and progress will appear here as this climber starts logging sessions."
          icon="hero-sparkles"
        />
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

  defp profile_name(user) do
    case user.display_name do
      name when is_binary(name) and name != "" -> name
      _ -> user.username
    end
  end

  defp profile_bio(user) do
    case user.bio do
      bio when is_binary(bio) and bio != "" -> bio
      _ -> "No bio yet."
    end
  end

  defp profile_initials(user) do
    user
    |> profile_name()
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp profile_avatar_url(scope, user) do
    if Media.authorized?(scope, {:user, user}) do
      Media.signed_url(user.avatar_object_key)
    end
  end
end
