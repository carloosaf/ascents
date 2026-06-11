defmodule AscentsWeb.GymLive.Show do
  use AscentsWeb, :live_view

  alias Ascents.Feed
  alias Ascents.Feed.{Comment, Post}
  alias Ascents.Gyms
  alias Ascents.Media
  alias Ascents.Routes, as: ClimbingRoutes
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:post_form, to_form(Feed.change_post(%Post{})))
     |> assign(:comment_form, to_form(Feed.change_comment(%Comment{})))
     |> assign(:post_modal_open?, false)
     |> allow_upload(:image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: Media.max_file_size()
     )
     |> assign_gym_state(gym)}
  end

  def handle_event("join", _params, socket) do
    if socket.assigns.current_scope do
      case Gyms.join_gym(socket.assigns.current_scope, socket.assigns.gym) do
        {:ok, _membership} ->
          {:noreply,
           socket
           |> put_flash(:info, "Joined #{socket.assigns.gym.name}.")
           |> assign_gym_state(socket.assigns.gym)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply, put_flash(socket, :error, "You already belong to this gym.")}

        {:error, :unauthorized} ->
          {:noreply, redirect_to_login(socket)}
      end
    else
      {:noreply, redirect_to_login(socket)}
    end
  end

  def handle_event("leave", _params, socket) do
    case Gyms.leave_gym(socket.assigns.current_scope, socket.assigns.gym) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Left #{socket.assigns.gym.name}.")
         |> assign_gym_state(socket.assigns.gym)}

      {:error, :only_owner} ->
        {:noreply, put_flash(socket, :error, "The only owner cannot leave this gym.")}

      {:error, :not_member} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not a member of this gym.")
         |> assign_gym_state(socket.assigns.gym)}

      {:error, :unauthorized} ->
        {:noreply, redirect_to_login(socket)}
    end
  end

  def handle_event("open-post-modal", _params, socket) do
    {:noreply, assign(socket, :post_modal_open?, true)}
  end

  def handle_event("close-post-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:post_modal_open?, false)
     |> assign(:post_form, to_form(Feed.change_post(%Post{})))}
  end

  def handle_event("validate-post", %{"post" => post_params}, socket) do
    changeset =
      socket
      |> post_for_form()
      |> Feed.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :post_form, to_form(changeset))}
  end

  def handle_event("create-post", %{"post" => post_params}, socket) do
    case put_uploaded_image(socket, post_params) do
      {:ok, post_params} ->
        case Feed.create_post(socket.assigns.current_scope, socket.assigns.gym, post_params) do
          {:ok, _post} ->
            {:noreply,
             socket
             |> put_flash(:info, "Post published.")
             |> assign(:post_modal_open?, false)
             |> assign(:post_form, to_form(Feed.change_post(%Post{})))
             |> assign_gym_state(socket.assigns.gym)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             assign(socket, :post_form, to_form(Map.put(changeset, :action, :validate)))}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "Join this gym before posting.")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("comment", %{"post_id" => post_id, "comment" => comment_params}, socket) do
    case Feed.get_post(socket.assigns.gym, post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      %Post{} = post ->
        case Feed.create_comment(
               socket.assigns.current_scope,
               socket.assigns.gym,
               post,
               comment_params
             ) do
          {:ok, _comment} ->
            {:noreply,
             socket
             |> assign(:comment_form, to_form(Feed.change_comment(%Comment{})))
             |> stream_insert(:posts, Feed.get_post(socket.assigns.gym, post.id))}

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
    case Feed.get_post(socket.assigns.gym, post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      %Post{} = post ->
        case Feed.delete_post(socket.assigns.current_scope, socket.assigns.gym, post) do
          {:ok, _post} ->
            {:noreply, assign_gym_state(socket, socket.assigns.gym)}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can only delete your own posts.")}
        end
    end
  end

  def handle_event("delete-comment", %{"post_id" => post_id, "id" => comment_id}, socket) do
    with %Post{} = post <- Feed.get_post(socket.assigns.gym, post_id),
         %Comment{} = comment <- find_comment(post, comment_id) do
      case Feed.delete_comment(socket.assigns.current_scope, socket.assigns.gym, post, comment) do
        {:ok, _comment} ->
          {:noreply, stream_insert(socket, :posts, Feed.get_post(socket.assigns.gym, post.id))}

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
      <div id="gym-show" class="space-y-8">
        <.gym_header
          name={@gym.name}
          location={@gym.location || "Location TBD"}
          members={Integer.to_string(@member_count)}
          active_routes={Integer.to_string(@active_route_count)}
          image_url={Media.signed_url(@gym.image_object_key)}
        />

        <section class="flex flex-wrap items-center justify-between gap-4">
          <div class="flex flex-wrap gap-2">
            <span class="rounded-md border border-ascents-line bg-ascents-panel px-3 py-1.5 text-sm font-bold text-ascents-chalk">
              {grade_scale_label(@gym.grade_scale)}
            </span>
            <span
              :if={@membership}
              class="rounded-md bg-ascents-tape px-3 py-1.5 text-sm font-black text-ascents-tape-content"
            >
              {@membership.role}
            </span>
          </div>

          <div class="flex flex-wrap gap-3">
            <.button :if={!@current_scope} navigate={~p"/users/log-in"} variant="secondary">
              Log in to join
            </.button>
            <.button
              :if={@current_scope && !@membership}
              id="gym-join-button"
              phx-click="join"
              variant="primary"
            >
              <.icon name="hero-user-plus" class="size-4" /> Join gym
            </.button>
            <.button
              :if={@current_scope && @membership}
              id="gym-leave-button"
              phx-click="leave"
              variant="secondary"
            >
              <.icon name="hero-user-minus" class="size-4" /> Leave gym
            </.button>
            <.button
              :if={@can_manage_routes?}
              id="gym-routes-link"
              navigate={~p"/gyms/#{@gym.slug}/problems"}
              variant="secondary"
            >
              <.icon name="hero-map" class="size-4" /> Routes
            </.button>
            <.button
              :if={@can_update_gym?}
              id="gym-settings-link"
              navigate={~p"/gyms/#{@gym.slug}/settings"}
              variant="secondary"
            >
              <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
            </.button>
            <.button
              :if={@can_manage_members?}
              id="gym-members-link"
              navigate={~p"/gyms/#{@gym.slug}/members"}
              variant="secondary"
            >
              <.icon name="hero-users" class="size-4" /> Members
            </.button>
          </div>
        </section>

        <section id="gym-feed" class="space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-black text-ascents-chalk">Gym feed</h2>
              <p class="mt-1 text-sm text-ascents-muted">
                Community posts from members of {@gym.name}.
              </p>
            </div>
            <.button
              :if={@membership}
              id="gym-new-post-button"
              phx-click="open-post-modal"
              variant="primary"
            >
              <.icon name="hero-pencil-square" class="size-4" /> New post
            </.button>
          </div>

          <.empty_state
            :if={!@membership && @current_scope}
            title="Join to post"
            description="Members can publish posts and comments in this gym feed."
            icon="hero-user-plus"
          />

          <div id="gym-feed-posts" phx-update="stream" class="space-y-4">
            <.empty_state
              :if={@posts_empty?}
              id="gym-feed-empty"
              title="No posts yet"
              description="Member posts will appear here."
              icon="hero-chat-bubble-left-right"
            />

            <.feed_post
              :for={{id, post} <- @streams.posts}
              id={id}
              post={post}
              current_scope={@current_scope}
              comment_form={@comment_form}
              show_gym?={false}
            />
          </div>
        </section>

        <section class="chalk-panel relative rounded-lg border border-ascents-line p-6">
          <h2 class="text-lg font-black text-ascents-chalk">About</h2>
          <p id="gym-description" class="mt-3 max-w-3xl text-sm leading-6 text-ascents-chalk-soft">
            {@gym.description || "No description yet."}
          </p>
        </section>

        <section id="gym-active-routes" class="space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-black text-ascents-chalk">Active routes</h2>
              <p class="mt-1 text-sm text-ascents-muted">
                Current boulder problems for this gym.
              </p>
            </div>
            <.button
              :if={@can_manage_routes?}
              id="gym-new-route-link"
              navigate={~p"/gyms/#{@gym.slug}/problems/new"}
              variant="primary"
            >
              <.icon name="hero-plus" class="size-4" /> Add route
            </.button>
          </div>

          <.empty_state
            :if={@active_problems == []}
            title="No routes yet"
            description="Gym admins can add active boulder problems from route management."
            icon="hero-map"
          />

          <div
            :if={@active_problems != []}
            id="gym-active-route-list"
            class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
          >
            <.route_card
              :for={problem <- @active_problems}
              id={"gym-route-card-#{problem.id}"}
              title={problem.title}
              gym={@gym.name}
              grade={problem.grade}
              status="Active"
              meta={problem.description || problem.color}
              image_url={Media.signed_url(problem.image_object_key)}
            />
          </div>
        </section>

        <div
          :if={@post_modal_open?}
          id="gym-post-modal"
          class="fixed inset-0 z-50 flex items-center justify-center bg-ascents-ink/80 px-4 py-8 backdrop-blur-sm"
        >
          <button
            type="button"
            class="absolute inset-0 cursor-default"
            phx-click="close-post-modal"
            aria-label="Close post modal"
          >
          </button>
          <section class="chalk-panel relative z-10 w-full max-w-2xl rounded-lg border border-ascents-line p-5 shadow-2xl shadow-black/40 sm:p-6">
            <div class="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 class="text-lg font-black text-ascents-chalk">New post</h2>
                <p class="mt-1 text-sm text-ascents-muted">
                  Share an update with {@gym.name}.
                </p>
              </div>
              <button
                id="gym-post-modal-close"
                type="button"
                phx-click="close-post-modal"
                class="rounded-md p-2 text-ascents-muted transition hover:bg-ascents-panel-hover hover:text-ascents-chalk"
                aria-label="Close"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>

            <.form
              for={@post_form}
              id="gym-post-form"
              phx-change="validate-post"
              phx-submit="create-post"
            >
              <.input
                field={@post_form[:body]}
                type="textarea"
                label="Post"
                placeholder="Share beta, session notes, or gym updates"
              />
              <div class="mb-4">
                <label for={@uploads.image.ref} class="block">
                  <span class="mb-1.5 block text-sm font-semibold text-ascents-chalk">
                    Image
                  </span>
                  <.live_file_input
                    upload={@uploads.image}
                    class="block w-full rounded-md border border-ascents-line bg-ascents-panel-deep px-3 py-2.5 text-sm text-ascents-chalk file:mr-3 file:rounded-md file:border-0 file:bg-ascents-action file:px-3 file:py-1.5 file:text-sm file:font-bold file:text-ascents-action-content hover:file:bg-ascents-action-hover"
                  />
                </label>
                <p class="mt-1.5 text-xs text-ascents-muted">
                  Optional JPG, PNG, or WebP up to 5 MB.
                </p>
                <p
                  :for={err <- upload_errors(@uploads.image)}
                  class="mt-1.5 text-sm text-ascents-danger-hover"
                >
                  {upload_error_message(err)}
                </p>
              </div>
              <.button id="gym-post-submit" variant="primary" phx-disable-with="Posting...">
                <.icon name="hero-paper-airplane" class="size-4" /> Post
              </.button>
            </.form>
          </section>
        </div>

        <section>
          <.empty_state
            title="No ascents yet"
            description="Structured ascent history will use this gym's route data later."
            icon="hero-sparkles"
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_gym_state(socket, gym) do
    gym = Gyms.get_gym!(gym.id)
    current_scope = socket.assigns.current_scope
    posts = Feed.list_gym_posts(gym)

    socket
    |> assign(
      gym: gym,
      membership: Gyms.get_membership(current_scope, gym),
      member_count: Gyms.count_gym_memberships(gym),
      active_route_count: ClimbingRoutes.count_active_boulder_problems(gym),
      active_problems: ClimbingRoutes.list_boulder_problems(gym),
      posts_empty?: posts == [],
      can_update_gym?: Gyms.can_update_gym?(current_scope, gym),
      can_manage_members?: Gyms.can_manage_members?(current_scope, gym),
      can_manage_routes?: Gyms.can_manage_routes?(current_scope, gym)
    )
    |> stream(:posts, posts, reset: true)
  end

  defp redirect_to_login(socket) do
    socket
    |> put_flash(:error, "You must log in to join this gym.")
    |> push_navigate(to: ~p"/users/log-in")
  end

  defp grade_scale_label("french"), do: "French bouldering"
  defp grade_scale_label(_grade_scale), do: "V scale"

  defp put_uploaded_image(socket, attrs) do
    case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
           result = Media.upload_image(:post, path, entry.client_name, entry.client_type)
           {:ok, result}
         end) do
      [] -> {:ok, attrs}
      [{:ok, key}] -> {:ok, Map.put(attrs, "image_object_key", key)}
      [{:error, reason}] -> {:error, upload_error_message(reason)}
    end
  end

  defp find_comment(%Post{} = post, comment_id) do
    Enum.find(post.comments, &(to_string(&1.id) == to_string(comment_id)))
  end

  defp post_for_form(socket) do
    %Post{
      gym_id: socket.assigns.gym.id,
      user_id: current_user_id(socket.assigns.current_scope)
    }
  end

  defp current_user_id(%{user: %{id: id}}), do: id
  defp current_user_id(_scope), do: nil

  defp upload_error_message(:too_large), do: "Choose an image up to 5 MB."
  defp upload_error_message(:not_accepted), do: "Choose a JPG, PNG, or WebP image."
  defp upload_error_message(:invalid_content_type), do: "Choose a JPG, PNG, or WebP image."
  defp upload_error_message(:invalid_extension), do: "Choose a JPG, PNG, or WebP image."
  defp upload_error_message(:missing_bucket), do: "Storage is not ready. Check the MinIO bucket."
  defp upload_error_message(_reason), do: "The image could not be uploaded."
end
