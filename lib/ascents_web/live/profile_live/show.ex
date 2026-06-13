defmodule AscentsWeb.ProfileLive.Show do
  use AscentsWeb, :live_view

  alias Ascents.Accounts
  alias Ascents.Accounts.Scope
  alias Ascents.Feed
  alias Ascents.Feed.{Comment, Post}

  def mount(%{"username" => username}, session, socket) do
    current_scope =
      session
      |> Map.get("user_token")
      |> scope_from_token()

    if current_scope do
      profile_user = Accounts.get_user_by_username!(username)
      posts = Feed.list_user_posts(profile_user)

      {:ok,
       socket
       |> assign(
         current_scope: current_scope,
         profile_user: profile_user,
         posts_empty?: posts == [],
         comment_form: to_form(Feed.change_comment(%Comment{}))
       )
       |> stream(:posts, posts)}
    else
      {:ok, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("comment", %{"post_id" => post_id, "comment" => comment_params}, socket) do
    case Feed.get_user_post(socket.assigns.profile_user, post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      %Post{} = post ->
        case Feed.create_comment(socket.assigns.current_scope, post.gym, post, comment_params) do
          {:ok, _comment} ->
            {:noreply,
             socket
             |> assign(:comment_form, to_form(Feed.change_comment(%Comment{})))
             |> stream_insert(:posts, Feed.get_user_post(socket.assigns.profile_user, post.id))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             assign(socket, :comment_form, to_form(Map.put(changeset, :action, :validate)))}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "Join this gym before commenting.")}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Post not found.")}
        end
    end
  end

  def handle_event("delete-post", %{"id" => post_id}, socket) do
    case Feed.get_user_post(socket.assigns.profile_user, post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      %Post{} = post ->
        case Feed.delete_post(socket.assigns.current_scope, post.gym, post) do
          {:ok, _post} ->
            {:noreply, refresh_profile_posts(socket)}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can only delete your own posts.")}
        end
    end
  end

  def handle_event("delete-comment", %{"post_id" => post_id, "id" => comment_id}, socket) do
    with %Post{} = post <- Feed.get_user_post(socket.assigns.profile_user, post_id),
         %Comment{} = comment <- find_comment(post, comment_id) do
      case Feed.delete_comment(socket.assigns.current_scope, post.gym, post, comment) do
        {:ok, _comment} ->
          {:noreply,
           stream_insert(socket, :posts, Feed.get_user_post(socket.assigns.profile_user, post.id))}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "You can only delete your own comments.")}
      end
    else
      _missing -> {:noreply, put_flash(socket, :error, "Comment not found.")}
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
                <.profile_picture
                  id="profile-avatar"
                  user={@profile_user}
                  size="xl"
                  class="border border-ascents-line shadow-xl"
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
            </div>
          </div>

          <div class="border-t border-ascents-line bg-ascents-panel p-6">
            <p id="profile-bio" class="max-w-3xl text-sm leading-6 text-ascents-chalk-soft">
              {profile_bio(@profile_user)}
            </p>
          </div>
        </section>

        <section id="profile-feed" class="space-y-4">
          <div>
            <h2 class="text-lg font-black text-ascents-chalk">Posts</h2>
            <p class="mt-1 text-sm text-ascents-muted">
              Recent gym posts and ascents from {profile_name(@profile_user)}.
            </p>
          </div>

          <div id="profile-feed-posts" phx-update="stream" class="space-y-4">
            <.empty_state
              :if={@posts_empty?}
              id="profile-feed-empty"
              title="No posts yet"
              description="This climber's gym posts will appear here."
              icon="hero-chat-bubble-left-right"
            />

            <.feed_post
              :for={{id, post} <- @streams.posts}
              id={id}
              post={post}
              current_scope={@current_scope}
              comment_form={@comment_form}
              show_gym?={true}
              show_owner_actions={false}
            />
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp refresh_profile_posts(socket) do
    posts = Feed.list_user_posts(socket.assigns.profile_user)

    socket
    |> assign(:posts_empty?, posts == [])
    |> stream(:posts, posts, reset: true)
  end

  defp find_comment(%Post{} = post, comment_id) do
    Enum.find(post.comments, &(to_string(&1.id) == to_string(comment_id)))
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
end
