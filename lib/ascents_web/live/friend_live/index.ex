defmodule AscentsWeb.FriendLive.Index do
  use AscentsWeb, :live_view

  alias Ascents.{Accounts, Friends}
  alias AscentsWeb.UserAuth

  @search_limit 20

  def mount(_params, session, socket) do
    case UserAuth.current_scope_from_session(session) do
      %{user: %{} = _user} = current_scope ->
        {:ok,
         socket
         |> assign(
           current_scope: current_scope,
           search_limit: @search_limit,
           search_form: to_form(%{"query" => ""}, as: :search),
           search_query: "",
           search_started?: false,
           search_results_empty?: true,
           search_result_ids: MapSet.new()
         )
         |> stream(:search_results, [])
         |> refresh_relationship_lists()}

      _scope ->
        {:ok, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("search", %{"search" => search_params}, socket) do
    query = search_params |> Map.get("query", "") |> String.trim()

    {:noreply,
     socket
     |> assign(
       search_form: to_form(%{"query" => query}, as: :search),
       search_query: query,
       search_started?: query != ""
     )
     |> refresh_search_results()}
  end

  def handle_event("send-request", %{"user-id" => user_id}, socket) do
    with {:ok, recipient_id} <- parse_user_id(user_id),
         true <- MapSet.member?(socket.assigns.search_result_ids, recipient_id),
         %{} = recipient <- Accounts.get_user(recipient_id) do
      case Friends.send_request(socket.assigns.current_scope, recipient) do
        {:ok, _friendship} ->
          {:noreply,
           socket
           |> put_flash(:info, "Friend request sent.")
           |> refresh_relationship_lists()
           |> refresh_search_results()}

        {:error, :cannot_friend_self} ->
          {:noreply, put_flash(socket, :error, "You cannot send a friend request to yourself.")}

        {:error, :relationship_exists} ->
          {:noreply,
           socket
           |> put_flash(:error, "A relationship with this climber already exists.")
           |> refresh_relationship_lists()
           |> refresh_search_results()}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "You must log in to send friend requests.")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Friend request could not be sent.")}
      end
    else
      _invalid_or_unsearched_user ->
        {:noreply, put_flash(socket, :error, "Friend request could not be sent.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="friends-page" class="space-y-8">
        <header class="route-hold-field chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <span class="hold absolute right-[8%] top-[16%] size-10 rotate-[18deg] bg-ascents-tape opacity-80">
          </span>
          <span class="hold absolute bottom-[12%] right-[24%] size-8 rotate-[-22deg] bg-grade-blue opacity-70">
          </span>

          <div class="relative z-10 max-w-2xl">
            <p class="text-xs font-black uppercase tracking-[0.2em] text-ascents-route-subtitle">
              Climb together
            </p>
            <h1 class="ascents-display mt-3 text-4xl leading-none text-ascents-route-title sm:text-5xl">
              Friends
            </h1>
            <p class="mt-4 text-sm leading-6 text-ascents-chalk-soft sm:text-base">
              Find climbers by username or display name, then keep track of your requests and crew.
            </p>
          </div>
        </header>

        <section
          id="friend-discovery"
          class="chalk-panel rounded-lg border border-ascents-line p-5 sm:p-6"
        >
          <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h2 class="text-xl font-black text-ascents-chalk">Find climbers</h2>
              <p class="mt-1 text-sm text-ascents-muted">
                Search matches usernames and public display names.
              </p>
            </div>
            <span class="text-xs font-bold uppercase tracking-wide text-ascents-muted">
              Up to {@search_limit} results
            </span>
          </div>

          <.form
            for={@search_form}
            id="friend-search-form"
            phx-change="search"
            phx-submit="search"
            class="mt-5 grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto]"
          >
            <.input
              field={@search_form[:query]}
              type="search"
              label="Username or display name"
              placeholder="Search climbers"
              autocomplete="off"
              maxlength="80"
              phx-debounce="250"
            />
            <.button id="friend-search-submit" type="submit" class="mb-4 sm:self-end">
              <.icon name="hero-magnifying-glass" class="size-4" /> Search
            </.button>
          </.form>

          <div id="friend-search-feedback" class="mt-2">
            <.empty_state
              :if={!@search_started?}
              id="friend-search-prompt"
              title="Search for your crew"
              description="Try a username or the name they use on their profile."
              icon="hero-magnifying-glass"
            />

            <.empty_state
              :if={@search_started? && @search_results_empty?}
              id="friend-search-empty"
              title="No climbers found"
              description="Check the spelling or try a shorter search."
              icon="hero-user-minus"
            />
          </div>

          <div id="friend-search-results" phx-update="stream" class="mt-3 space-y-3">
            <article
              :for={{id, result} <- @streams.search_results}
              id={id}
              class="ascents-stream-item flex flex-col gap-4 rounded-lg border border-ascents-line bg-ascents-panel-deep p-4 sm:flex-row sm:items-center sm:justify-between"
            >
              <.profile_link
                id={"friend-search-profile-#{result.user.id}"}
                user={result.user}
              />

              <div class="flex shrink-0 items-center gap-3">
                <span
                  id={"friend-search-state-#{result.user.id}"}
                  data-state={result.relationship_state}
                  class={[
                    "rounded-md px-2.5 py-1 text-xs font-black uppercase tracking-wide",
                    relationship_state_class(result.relationship_state)
                  ]}
                >
                  {relationship_state_label(result.relationship_state)}
                </span>
                <.button
                  :if={result.relationship_state in [:none, :declined]}
                  id={"friend-search-send-#{result.user.id}"}
                  type="button"
                  phx-click="send-request"
                  phx-value-user-id={result.user.id}
                  phx-disable-with="Sending..."
                >
                  <.icon name="hero-user-plus" class="size-4" /> Add friend
                </.button>
              </div>
            </article>
          </div>
        </section>

        <div class="grid gap-6 xl:grid-cols-2">
          <section
            id="incoming-requests-section"
            class="chalk-panel rounded-lg border border-ascents-line p-5 sm:p-6"
          >
            <div class="flex items-center gap-3">
              <span class="flex size-10 items-center justify-center rounded-md bg-ascents-tape text-ascents-tape-content">
                <.icon name="hero-inbox-arrow-down" class="size-5" />
              </span>
              <div>
                <h2 class="text-lg font-black text-ascents-chalk">Incoming requests</h2>
                <p class="text-sm text-ascents-muted">Climbers waiting for your response.</p>
              </div>
            </div>

            <.empty_state
              :if={@incoming_empty?}
              id="incoming-requests-empty"
              title="No incoming requests"
              description="New friend requests will appear here."
              icon="hero-inbox"
              class="mt-5"
            />

            <div id="incoming-requests" phx-update="stream" class="mt-5 space-y-3">
              <article
                :for={{id, friendship} <- @streams.incoming_requests}
                id={id}
                class="ascents-stream-item rounded-lg border border-ascents-line bg-ascents-panel-deep p-4"
              >
                <.profile_link
                  id={"incoming-request-profile-#{friendship.id}"}
                  user={friendship.requester}
                />
                <p class="mt-3 text-xs font-bold uppercase tracking-wide text-ascents-tape">
                  Wants to be friends
                </p>
              </article>
            </div>
          </section>

          <section
            id="outgoing-requests-section"
            class="chalk-panel rounded-lg border border-ascents-line p-5 sm:p-6"
          >
            <div class="flex items-center gap-3">
              <span class="flex size-10 items-center justify-center rounded-md bg-grade-blue/20 text-grade-blue">
                <.icon name="hero-paper-airplane" class="size-5" />
              </span>
              <div>
                <h2 class="text-lg font-black text-ascents-chalk">Sent requests</h2>
                <p class="text-sm text-ascents-muted">Pending invitations you have sent.</p>
              </div>
            </div>

            <.empty_state
              :if={@outgoing_empty?}
              id="outgoing-requests-empty"
              title="No sent requests"
              description="Search above to invite another climber."
              icon="hero-paper-airplane"
              class="mt-5"
            />

            <div id="outgoing-requests" phx-update="stream" class="mt-5 space-y-3">
              <article
                :for={{id, friendship} <- @streams.outgoing_requests}
                id={id}
                class="ascents-stream-item rounded-lg border border-ascents-line bg-ascents-panel-deep p-4"
              >
                <.profile_link
                  id={"outgoing-request-profile-#{friendship.id}"}
                  user={friendship.recipient}
                />
                <p class="mt-3 text-xs font-bold uppercase tracking-wide text-grade-blue">
                  Request pending
                </p>
              </article>
            </div>
          </section>
        </div>

        <section
          id="accepted-friends-section"
          class="chalk-panel rounded-lg border border-ascents-line p-5 sm:p-6"
        >
          <div class="flex items-center gap-3">
            <span class="flex size-10 items-center justify-center rounded-md bg-ascents-action/20 text-ascents-action">
              <.icon name="hero-user-group" class="size-5" />
            </span>
            <div>
              <h2 class="text-lg font-black text-ascents-chalk">Your friends</h2>
              <p class="text-sm text-ascents-muted">Accepted connections in your climbing crew.</p>
            </div>
          </div>

          <.empty_state
            :if={@friends_empty?}
            id="accepted-friends-empty"
            title="No friends yet"
            description="Find a climber above and send your first request."
            icon="hero-user-group"
            class="mt-5"
          />

          <div
            id="accepted-friends"
            phx-update="stream"
            class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-3"
          >
            <article
              :for={{id, friend} <- @streams.friends}
              id={id}
              class="ascents-stream-item rounded-lg border border-ascents-line bg-ascents-panel-deep p-4 transition hover:-translate-y-0.5 hover:border-ascents-action/50"
            >
              <.profile_link id={"accepted-friend-profile-#{friend.id}"} user={friend} />
              <p class="mt-3 text-xs font-bold uppercase tracking-wide text-ascents-action">
                Friends
              </p>
            </article>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :user, :map, required: true

  defp profile_link(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={~p"/u/#{@user.username}"}
      class="group flex min-w-0 items-center gap-3"
    >
      <.profile_picture user={@user} size="md" />
      <span class="min-w-0">
        <span class="block truncate font-black text-ascents-chalk transition group-hover:text-white">
          {profile_name(@user)}
        </span>
        <span class="block truncate text-sm text-ascents-muted">@{@user.username}</span>
      </span>
    </.link>
    """
  end

  defp refresh_relationship_lists(socket) do
    incoming = Friends.list_incoming_requests(socket.assigns.current_scope)
    outgoing = Friends.list_outgoing_requests(socket.assigns.current_scope)
    friends = Friends.list_friends(socket.assigns.current_scope)

    socket
    |> assign(
      incoming_empty?: incoming == [],
      outgoing_empty?: outgoing == [],
      friends_empty?: friends == []
    )
    |> stream(:incoming_requests, incoming, reset: true)
    |> stream(:outgoing_requests, outgoing, reset: true)
    |> stream(:friends, friends, reset: true)
  end

  defp refresh_search_results(socket) do
    users =
      socket.assigns.current_scope
      |> Accounts.search_profiles(socket.assigns.search_query, limit: @search_limit)

    relationship_states = Friends.relationship_states(socket.assigns.current_scope, users)

    results =
      Enum.map(users, fn user ->
        %{
          id: user.id,
          user: user,
          relationship_state: Map.fetch!(relationship_states, user.id)
        }
      end)

    socket
    |> assign(
      search_results_empty?: results == [],
      search_result_ids: MapSet.new(users, & &1.id)
    )
    |> stream(:search_results, results, reset: true)
  end

  defp parse_user_id(user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {id, ""} -> {:ok, id}
      _invalid -> :error
    end
  end

  defp parse_user_id(_user_id), do: :error

  defp profile_name(%{display_name: display_name})
       when is_binary(display_name) and display_name != "",
       do: display_name

  defp profile_name(%{username: username}), do: username

  defp relationship_state_label(:friends), do: "Friends"
  defp relationship_state_label(:incoming_pending), do: "Respond pending"
  defp relationship_state_label(:outgoing_pending), do: "Request sent"
  defp relationship_state_label(:declined), do: "Available"
  defp relationship_state_label(:none), do: "Not connected"

  defp relationship_state_class(:friends), do: "bg-ascents-action/20 text-ascents-action"
  defp relationship_state_class(:incoming_pending), do: "bg-ascents-tape/20 text-ascents-tape"
  defp relationship_state_class(:outgoing_pending), do: "bg-grade-blue/20 text-grade-blue"
  defp relationship_state_class(:declined), do: "bg-ascents-panel-hover text-ascents-muted"
  defp relationship_state_class(:none), do: "bg-ascents-panel-hover text-ascents-muted"
end
