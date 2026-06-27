defmodule AscentsWeb.FeedLive.Index do
  use AscentsWeb, :live_view

  alias Ascents.Feed
  alias Ascents.Feed.{Comment, Post}
  alias AscentsWeb.UserAuth

  def mount(_params, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    posts = Feed.list_home_posts(current_scope)

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:posts_empty?, posts == [])
     |> assign(:comment_form, to_form(Feed.change_comment(%Comment{})))
     |> stream(:posts, posts)}
  end

  def handle_event("comment", %{"post_id" => post_id, "comment" => comment_params}, socket) do
    case Feed.get_home_post(socket.assigns.current_scope, post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      %Post{} = post ->
        case Feed.create_comment(socket.assigns.current_scope, post.gym, post, comment_params) do
          {:ok, _comment} ->
            {:noreply,
             socket
             |> assign(:comment_form, to_form(Feed.change_comment(%Comment{})))
             |> stream_insert(
               :posts,
               Feed.get_post(post.gym, post.id, socket.assigns.current_scope)
             )}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             assign(socket, :comment_form, to_form(Map.put(changeset, :action, :validate)))}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "Join this gym before commenting.")}
        end
    end
  end

  def handle_event("delete-post", %{"id" => post_id}, socket) do
    case Feed.get_home_post(socket.assigns.current_scope, post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      %Post{} = post ->
        case Feed.delete_post(socket.assigns.current_scope, post.gym, post) do
          {:ok, _post} ->
            {:noreply, refresh_posts(socket)}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can only delete your own posts.")}
        end
    end
  end

  def handle_event("delete-comment", %{"post_id" => post_id, "id" => comment_id}, socket) do
    with %Post{} = post <- Feed.get_home_post(socket.assigns.current_scope, post_id),
         %Comment{} = comment <- Feed.get_post_comment(post, comment_id) do
      case Feed.delete_comment(socket.assigns.current_scope, post.gym, post, comment) do
        {:ok, _comment} ->
          {:noreply,
           stream_insert(
             socket,
             :posts,
             Feed.get_post(post.gym, post.id, socket.assigns.current_scope)
           )}

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
      <div id="home-feed" class="space-y-6">
        <section class="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p class="text-sm font-bold uppercase text-ascents-tape">Joined gyms</p>
            <h1 class="ascents-display mt-2 text-4xl text-ascents-chalk">Feed</h1>
          </div>
          <.button navigate={~p"/gyms"} variant="secondary">
            <.icon name="hero-building-storefront" class="size-4" /> Find gyms
          </.button>
        </section>

        <div id="home-feed-posts" phx-update="stream" class="space-y-4">
          <.empty_state
            :if={@posts_empty?}
            id="home-feed-empty"
            title="No posts yet"
            description="Join gyms and their community posts will appear here."
            icon="hero-chat-bubble-left-right"
          />

          <.feed_post
            :for={{id, post} <- @streams.posts}
            id={id}
            post={post}
            current_scope={@current_scope}
            comment_form={@comment_form}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp refresh_posts(socket) do
    posts = Feed.list_home_posts(socket.assigns.current_scope)

    socket
    |> assign(:posts_empty?, posts == [])
    |> stream(:posts, posts, reset: true)
  end
end
