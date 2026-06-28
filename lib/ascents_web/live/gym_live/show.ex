defmodule AscentsWeb.GymLive.Show do
  use AscentsWeb, :live_view

  alias Ascents.Ascents, as: AscentLogs
  alias Ascents.Feed
  alias Ascents.Feed.{Comment, Post}
  alias Ascents.Gyms
  alias Ascents.Media
  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Sessions
  alias AscentsWeb.UserAuth

  @composer_auth_error "You are not allowed to post in this gym."

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)

    {:ok,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:post_form, to_form(Feed.change_post(%Post{})))
     |> assign_ascent_form(AscentLogs.change_ascent_post(default_ascent_attrs()))
     |> assign_session_form(Sessions.change_session(default_session_attrs()))
     |> assign(:session_row_order, [1])
     |> assign(:session_rows_by_id, %{1 => session_row(1)})
     |> assign(:next_session_row_id, 2)
     |> assign(:session_route_feedback?, false)
     |> assign(:comment_form, to_form(Feed.change_comment(%Comment{})))
     |> assign(:post_mode, "normal")
     |> assign(:post_modal_open?, false)
     |> stream_configure(:session_rows, dom_id: &"session-ascent-row-#{&1.id}")
     |> stream(:session_rows, [session_row(1)])
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
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        {:noreply, assign(socket, :post_modal_open?, true)}

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("close-post-modal", _params, socket) do
    {:noreply, reset_post_modal(socket)}
  end

  def handle_event("select-post-mode", %{"mode" => mode}, socket)
      when mode in ~w(normal ascent session) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        socket = assign(socket, :post_mode, mode)

        socket =
          if mode == "session" do
            stream(socket, :session_rows, ordered_session_rows(socket), reset: true)
          else
            socket
          end

        {:noreply, socket}

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("validate-post", %{"post" => post_params}, socket) do
    changeset =
      socket
      |> post_for_form()
      |> Feed.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :post_form, to_form(changeset))}
  end

  def handle_event("validate-ascent-post", %{"ascent_post" => ascent_params}, socket) do
    changeset =
      ascent_params
      |> AscentLogs.change_ascent_post()
      |> Map.put(:action, :validate)

    {:noreply, assign_ascent_form(socket, changeset)}
  end

  def handle_event("add-session-ascent", _params, socket) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        row_id = socket.assigns.next_session_row_id

        socket =
          socket
          |> assign(:session_row_order, socket.assigns.session_row_order ++ [row_id])
          |> assign(
            :session_rows_by_id,
            Map.put(socket.assigns.session_rows_by_id, row_id, session_row(row_id))
          )
          |> assign(:next_session_row_id, row_id + 1)
          |> assign(:session_route_feedback?, true)

        {:noreply, stream(socket, :session_rows, ordered_session_rows(socket), reset: true)}

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("remove-session-ascent", %{"row-id" => row_id}, socket)
      when is_binary(row_id) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        cond do
          length(socket.assigns.session_row_order) == 1 ->
            {:noreply, put_flash(socket, :error, "A session needs at least one ascent.")}

          true ->
            case Integer.parse(row_id) do
              {row_id, ""} ->
                if row_id in socket.assigns.session_row_order do
                  socket =
                    socket
                    |> assign(
                      :session_row_order,
                      List.delete(socket.assigns.session_row_order, row_id)
                    )
                    |> assign(
                      :session_rows_by_id,
                      Map.delete(socket.assigns.session_rows_by_id, row_id)
                    )

                  {:noreply,
                   stream(socket, :session_rows, ordered_session_rows(socket), reset: true)}
                else
                  {:noreply, socket}
                end

              _invalid ->
                {:noreply, socket}
            end
        end

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("remove-session-ascent", _params, socket), do: {:noreply, socket}

  def handle_event("validate-session", %{"session" => session_params} = params, socket) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        show_route_feedback? =
          socket.assigns.session_route_feedback? || session_route_target?(params)

        {session_attrs, rows} =
          session_attrs_and_rows(socket, session_params, show_route_feedback?)

        changeset =
          session_attrs
          |> Sessions.change_session()
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign_session_form(changeset)
         |> assign(:session_route_feedback?, show_route_feedback?)
         |> assign(:session_rows_by_id, Map.new(rows, &{&1.id, &1}))
         |> stream(:session_rows, rows, reset: true)}

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("create-post", %{"post" => post_params}, socket) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        case put_uploaded_image(socket, post_params) do
          {:ok, post_params, _uploaded_object_key} ->
            case Feed.create_post(socket.assigns.current_scope, socket.assigns.gym, post_params) do
              {:ok, _post} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Post published.")
                 |> reset_post_modal()
                 |> assign_gym_state(socket.assigns.gym)}

              {:error, %Ecto.Changeset{} = changeset} ->
                {:noreply,
                 assign(socket, :post_form, to_form(Map.put(changeset, :action, :validate)))}

              {:error, :unauthorized} ->
                {:noreply, deny_composer_action(socket)}
            end

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("create-ascent-post", %{"ascent_post" => ascent_params}, socket) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        case put_uploaded_image(socket, ascent_params) do
          {:ok, ascent_params, _uploaded_object_key} ->
            case AscentLogs.create_ascent_post(
                   socket.assigns.current_scope,
                   socket.assigns.gym,
                   ascent_params
                 ) do
              {:ok, _result} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Ascent posted.")
                 |> reset_post_modal()
                 |> assign_gym_state(socket.assigns.gym)}

              {:error, %Ecto.Changeset{} = changeset} ->
                {:noreply, assign_ascent_form(socket, Map.put(changeset, :action, :validate))}

              {:error, :unauthorized} ->
                {:noreply, deny_composer_action(socket)}
            end

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("create-session", %{"session" => session_params}, socket) do
    case ensure_composer_authorized(socket) do
      {:ok, socket} ->
        {session_attrs, rows} = session_attrs_and_rows(socket, session_params, true)

        case put_uploaded_image(socket, session_attrs) do
          {:ok, session_attrs, uploaded_object_key} ->
            case Sessions.create_session(
                   socket.assigns.current_scope,
                   socket.assigns.gym,
                   session_attrs
                 ) do
              {:ok, _result} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Session posted.")
                 |> reset_post_modal()
                 |> assign_gym_state(socket.assigns.gym)}

              {:error, %Ecto.Changeset{} = changeset} ->
                delete_uploaded_image(uploaded_object_key)

                {:noreply,
                 socket
                 |> assign_session_form(Map.put(changeset, :action, :validate))
                 |> assign(:session_route_feedback?, true)
                 |> assign(:session_rows_by_id, Map.new(rows, &{&1.id, &1}))
                 |> stream(:session_rows, rows, reset: true)}

              {:error, :unauthorized} ->
                delete_uploaded_image(uploaded_object_key)
                {:noreply, deny_composer_action(socket)}

              {:error, _reason} ->
                delete_uploaded_image(uploaded_object_key)
                {:noreply, put_flash(socket, :error, "Session could not be posted.")}
            end

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end

      {:error, socket} ->
        {:noreply, deny_composer_action(socket)}
    end
  end

  def handle_event("comment", %{"post_id" => post_id, "comment" => comment_params}, socket) do
    case Feed.get_post(socket.assigns.current_scope, socket.assigns.gym, post_id) do
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
             |> stream_insert(
               :posts,
               Feed.get_post(socket.assigns.current_scope, socket.assigns.gym, post.id)
             )}

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
    case Feed.get_post(socket.assigns.current_scope, socket.assigns.gym, post_id) do
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
    with %Post{} = post <-
           Feed.get_post(socket.assigns.current_scope, socket.assigns.gym, post_id),
         %Comment{} = comment <-
           Feed.get_post_comment(socket.assigns.current_scope, post, comment_id) do
      case Feed.delete_comment(socket.assigns.current_scope, socket.assigns.gym, post, comment) do
        {:ok, _comment} ->
          {:noreply,
           stream_insert(
             socket,
             :posts,
             Feed.get_post(socket.assigns.current_scope, socket.assigns.gym, post.id)
           )}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "You can only delete your own comments.")}
      end
    else
      _missing -> {:noreply, put_flash(socket, :error, "Comment not found.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:modal>
        <div
          :if={@post_modal_open?}
          id="gym-post-modal"
          class="ascents-modal-overlay flex items-start justify-center overflow-y-auto bg-ascents-ink/85 px-4 py-6 backdrop-blur-sm sm:items-center sm:py-8"
        >
          <button
            type="button"
            class="absolute inset-0 cursor-default"
            phx-click="close-post-modal"
            aria-label="Close post modal"
          >
          </button>
          <section class="ascents-modal-panel chalk-panel relative z-10 my-auto w-full max-w-2xl rounded-lg border border-ascents-line p-5 shadow-2xl shadow-black/40 sm:p-6">
            <div class="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 class="text-lg font-black text-ascents-chalk">New post</h2>
                <p class="mt-1 text-sm text-ascents-muted">
                  Share an update, ascent, or full session at {@gym.name}.
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

            <div
              id="gym-post-mode-toggle"
              class="mb-5 grid grid-cols-3 gap-2 rounded-lg border border-ascents-line bg-ascents-panel-deep p-1"
            >
              <button
                id="gym-post-normal-mode"
                type="button"
                phx-click="select-post-mode"
                phx-value-mode="normal"
                class={[
                  "inline-flex min-h-10 items-center justify-center gap-2 rounded-md px-3 text-sm font-black transition",
                  @post_mode == "normal" &&
                    "bg-ascents-action text-ascents-action-content shadow-lg",
                  @post_mode != "normal" &&
                    "text-ascents-muted hover:bg-ascents-panel-hover hover:text-ascents-chalk"
                ]}
              >
                <.icon name="hero-chat-bubble-left-right" class="size-4" /> Post
              </button>
              <button
                id="gym-post-ascent-mode"
                type="button"
                phx-click="select-post-mode"
                phx-value-mode="ascent"
                class={[
                  "inline-flex min-h-10 items-center justify-center gap-2 rounded-md px-3 text-sm font-black transition",
                  @post_mode == "ascent" &&
                    "bg-ascents-tape text-ascents-tape-content shadow-lg",
                  @post_mode != "ascent" &&
                    "text-ascents-muted hover:bg-ascents-panel-hover hover:text-ascents-chalk"
                ]}
              >
                <.icon name="hero-sparkles" class="size-4" /> Ascent
              </button>
              <button
                id="gym-post-session-mode"
                type="button"
                phx-click="select-post-mode"
                phx-value-mode="session"
                class={[
                  "inline-flex min-h-10 items-center justify-center gap-2 rounded-md px-3 text-sm font-black transition",
                  @post_mode == "session" &&
                    "bg-grade-blue text-grade-blue-content shadow-lg",
                  @post_mode != "session" &&
                    "text-ascents-muted hover:bg-ascents-panel-hover hover:text-ascents-chalk"
                ]}
              >
                <.icon name="hero-rectangle-stack" class="size-4" /> Session
              </button>
            </div>

            <.form
              :if={@post_mode == "normal"}
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
              <.input
                field={@post_form[:visibility]}
                id="gym-post-visibility"
                type="select"
                label="Audience"
                options={post_visibility_options()}
              />
              <p id="gym-post-visibility-help" class="-mt-2 mb-4 text-xs text-ascents-muted">
                Friends-only posts will be limited to your accepted friends.
              </p>
              <.image_upload_input
                upload={@uploads.image}
                label="Image"
                help="Optional JPG, PNG, or WebP up to 5 MB."
              />
              <.button id="gym-post-submit" variant="primary" phx-disable-with="Posting...">
                <.icon name="hero-paper-airplane" class="size-4" /> Post
              </.button>
            </.form>

            <.form
              :if={@post_mode == "ascent"}
              for={@ascent_form}
              id="gym-ascent-post-form"
              phx-change="validate-ascent-post"
              phx-submit="create-ascent-post"
            >
              <.input
                field={@ascent_form[:boulder_problem_id]}
                type="select"
                label="Route"
                prompt="Choose an active route"
                options={active_problem_options(@active_problems)}
              />
              <.input
                field={@ascent_form[:climbed_at]}
                type="datetime-local"
                label="Climbed at"
              />
              <.input
                field={@ascent_form[:body]}
                type="textarea"
                label="Notes"
                placeholder="Optional beta, attempts, or session notes"
              />
              <.input
                field={@ascent_form[:visibility]}
                id="gym-ascent-post-visibility"
                type="select"
                label="Audience"
                options={ascent_visibility_options()}
              />
              <p id="gym-ascent-post-visibility-help" class="-mt-2 mb-4 text-xs text-ascents-muted">
                Private ascents are kept for your own log; friends-only ascents will be limited to your accepted friends.
              </p>
              <.image_upload_input
                upload={@uploads.image}
                label="Image"
                help="Optional JPG, PNG, or WebP up to 5 MB."
              />
              <div class="flex flex-wrap items-center gap-3">
                <.button id="gym-ascent-post-submit" variant="primary" phx-disable-with="Posting...">
                  <.icon name="hero-sparkles" class="size-4" /> Post ascent
                </.button>
                <p :if={@active_problems == []} class="text-sm text-ascents-muted">
                  This gym has no active routes to log yet.
                </p>
              </div>
            </.form>

            <.form
              :if={@post_mode == "session"}
              for={@session_form}
              id="gym-session-form"
              phx-change="validate-session"
              phx-submit="create-session"
            >
              <.input
                field={@session_form[:started_at]}
                id="gym-session-started-at"
                type="datetime-local"
                label="Climbed at"
              />

              <.input
                field={@session_form[:notes]}
                id="gym-session-notes"
                type="textarea"
                label="Notes"
                placeholder="Optional highlights, attempts, or beta"
              />

              <section class="mb-4 rounded-lg border border-ascents-line bg-ascents-panel-deep/70 p-3 sm:p-4">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h3 class="text-sm font-black text-ascents-chalk">Ascents</h3>
                    <p class="mt-1 text-xs text-ascents-muted">
                      Add every route sent in this session.
                    </p>
                  </div>
                  <button
                    id="gym-session-add-ascent"
                    type="button"
                    phx-click="add-session-ascent"
                    class="inline-flex min-h-9 items-center justify-center gap-2 rounded-md border border-ascents-line px-3 text-xs font-black text-ascents-chalk transition hover:border-ascents-tape hover:text-ascents-tape"
                  >
                    <.icon name="hero-plus" class="size-4" /> Add ascent
                  </button>
                </div>

                <div
                  id="gym-session-ascent-rows"
                  phx-update="stream"
                  class="mt-4 max-h-80 space-y-3 overflow-y-auto pr-1"
                >
                  <div
                    :for={{row_dom_id, row} <- @streams.session_rows}
                    id={row_dom_id}
                    data-row-id={row.id}
                    class="grid gap-2 rounded-md border border-ascents-line bg-ascents-panel p-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end"
                  >
                    <div id={"gym-session-route-field-#{row.id}"}>
                      <.input
                        id={"gym-session-route-#{row.id}"}
                        name={"session[ascents][#{row.id}][boulder_problem_id]"}
                        type="select"
                        label={"Route #{session_row_number(@session_row_order, row.id)}"}
                        prompt="Choose an active route"
                        options={active_problem_options(@active_problems)}
                        value={row.boulder_problem_id}
                        errors={row.errors}
                      />
                    </div>
                    <button
                      id={"gym-session-remove-ascent-#{row.id}"}
                      type="button"
                      phx-click="remove-session-ascent"
                      phx-value-row-id={row.id}
                      disabled={length(@session_row_order) == 1}
                      class="mb-4 inline-flex min-h-10 items-center justify-center gap-2 rounded-md border border-ascents-line px-3 text-sm font-bold text-ascents-muted transition hover:border-ascents-danger/50 hover:bg-ascents-danger/10 hover:text-ascents-danger-hover disabled:cursor-not-allowed disabled:opacity-40"
                      aria-label={"Remove route #{session_row_number(@session_row_order, row.id)}"}
                    >
                      <.icon name="hero-trash" class="size-4" />
                      <span class="sm:hidden">Remove</span>
                    </button>
                  </div>
                </div>
                <p
                  :for={error <- session_ascent_errors(@session_form)}
                  :if={@session_route_feedback?}
                  id="gym-session-ascents-error"
                  class="mt-2 text-sm text-ascents-danger-hover"
                >
                  {error}
                </p>
              </section>

              <.input
                field={@session_form[:visibility]}
                id="gym-session-visibility"
                type="select"
                label="Audience"
                options={post_visibility_options()}
              />
              <p id="gym-session-visibility-help" class="-mt-2 mb-4 text-xs text-ascents-muted">
                Friends-only sessions and their image are limited to accepted friends.
              </p>
              <.image_upload_input
                upload={@uploads.image}
                label="Session image"
                help="Optional JPG, PNG, or WebP up to 5 MB."
              />
              <div class="flex flex-wrap items-center gap-3">
                <.button id="gym-session-submit" variant="primary" phx-disable-with="Posting...">
                  <.icon name="hero-rectangle-stack" class="size-4" /> Post session
                </.button>
                <p :if={@active_problems == []} class="text-sm text-ascents-muted">
                  This gym has no active routes to log yet.
                </p>
              </div>
            </.form>
          </section>
        </div>
      </:modal>

      <div id="gym-show" class="space-y-8">
        <.gym_header
          name={@gym.name}
          location={@gym.location || "Location TBD"}
          members={Integer.to_string(@member_count)}
          active_routes={Integer.to_string(@active_route_count)}
          image_url={Media.signed_url(@gym.image_object_key)}
        />

        <section
          id="gym-verification-status"
          class={[
            "rounded-lg border p-4 sm:p-5",
            @gym.verification_status == "verified" &&
              "border-emerald-400/30 bg-emerald-400/5",
            @gym.verification_status == "pending" && "border-amber-400/30 bg-amber-400/5",
            @gym.verification_status == "community" &&
              "border-ascents-line bg-ascents-panel"
          ]}
        >
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex items-start gap-3">
              <div class={[
                "flex size-10 shrink-0 items-center justify-center rounded-lg",
                @gym.verification_status == "verified" &&
                  "bg-emerald-500/15 text-emerald-300",
                @gym.verification_status == "pending" && "bg-amber-500/15 text-amber-300",
                @gym.verification_status == "community" &&
                  "bg-ascents-panel-deep text-ascents-muted"
              ]}>
                <.icon name={verification_icon(@gym.verification_status)} class="size-5" />
              </div>
              <div>
                <div
                  id={"gym-verification-#{@gym.verification_status}-badge"}
                  class="inline-flex items-center gap-2 text-sm font-black text-ascents-chalk"
                >
                  {verification_title(@gym.verification_status)}
                </div>
                <p class="mt-1 max-w-3xl text-sm leading-6 text-ascents-muted">
                  {verification_description(@gym)}
                </p>
                <p
                  :if={@gym.verification_status == "verified" && @gym.verification_note}
                  id="gym-verification-note"
                  class="mt-2 text-sm leading-6 text-ascents-chalk-soft"
                >
                  {@gym.verification_note}
                </p>
              </div>
            </div>

            <.button
              :if={@can_access_verification_workflow?}
              id="gym-verification-link"
              navigate={~p"/gyms/#{@gym.slug}/verification"}
              variant="secondary"
            >
              <.icon name="hero-shield-check" class="size-4" /> Verification
            </.button>
          </div>
        </section>

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

        <div
          id="gym-content-grid"
          class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(20rem,24rem)] xl:items-start"
        >
          <section id="gym-feed" class="order-2 space-y-4 xl:order-1">
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

          <section
            id="gym-active-routes"
            class="order-1 space-y-4 xl:sticky xl:top-24 xl:order-2"
          >
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
              class="grid gap-3 sm:grid-cols-2 xl:grid-cols-1"
            >
              <.route_card
                :for={problem <- @active_problems}
                id={"gym-route-card-#{problem.id}"}
                title={problem.title}
                gym={@gym.name}
                grade={problem.grade}
                compact
                meta={problem.description || problem.color}
                image_url={Media.signed_url(problem.image_object_key)}
              />
            </div>
          </section>
        </div>

        <section class="chalk-panel relative rounded-lg border border-ascents-line p-6">
          <h2 class="text-lg font-black text-ascents-chalk">About</h2>
          <p id="gym-description" class="mt-3 max-w-3xl text-sm leading-6 text-ascents-chalk-soft">
            {@gym.description || "No description yet."}
          </p>
        </section>

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
    posts = Feed.list_gym_posts(current_scope, gym)

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
      can_manage_routes?: Gyms.can_manage_routes?(current_scope, gym),
      can_access_verification_workflow?:
        Gyms.can_access_verification_workflow?(current_scope, gym)
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

  defp verification_icon("verified"), do: "hero-check-badge"
  defp verification_icon("pending"), do: "hero-clock"
  defp verification_icon(_status), do: "hero-user-group"

  defp verification_title("verified"), do: "Official gym"
  defp verification_title("pending"), do: "Ownership review pending"
  defp verification_title(_status), do: "Community-managed"

  defp verification_description(%{verification_status: "verified", verified_at: verified_at}) do
    "Ownership manually verified by Ascents on #{Calendar.strftime(verified_at, "%B %-d, %Y")}."
  end

  defp verification_description(%{verification_status: "pending"}) do
    "An ownership claim is under manual review. This page is not official until approved."
  end

  defp verification_description(_gym) do
    "Route data and updates come from the climbing community, not a verified gym business."
  end

  defp put_uploaded_image(socket, attrs) do
    case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
           result = Media.upload_image(:post, path, entry.client_name, entry.client_type)
           {:ok, result}
         end) do
      [] -> {:ok, attrs, nil}
      [{:ok, key}] -> {:ok, Map.put(attrs, "image_object_key", key), key}
      [{:error, reason}] -> {:error, Media.upload_error_message(reason)}
    end
  end

  defp delete_uploaded_image(key) when is_binary(key) and key != "", do: Media.delete_object(key)
  defp delete_uploaded_image(_key), do: :ok

  defp post_for_form(socket) do
    %Post{
      gym_id: socket.assigns.gym.id,
      user_id: current_user_id(socket.assigns.current_scope)
    }
  end

  defp current_user_id(%{user: %{id: id}}), do: id
  defp current_user_id(_scope), do: nil

  defp reset_post_modal(socket) do
    socket
    |> assign(:post_modal_open?, false)
    |> assign(:post_mode, "normal")
    |> assign(:post_form, to_form(Feed.change_post(%Post{})))
    |> assign_ascent_form(AscentLogs.change_ascent_post(default_ascent_attrs()))
    |> assign_session_form(Sessions.change_session(default_session_attrs()))
    |> assign(:session_row_order, [1])
    |> assign(:session_rows_by_id, %{1 => session_row(1)})
    |> assign(:next_session_row_id, 2)
    |> assign(:session_route_feedback?, false)
    |> stream(:session_rows, [session_row(1)], reset: true)
  end

  defp assign_ascent_form(socket, changeset) do
    assign(socket, :ascent_form, to_form(changeset, as: :ascent_post))
  end

  defp assign_session_form(socket, changeset) do
    assign(socket, :session_form, to_form(changeset, as: :session))
  end

  defp active_problem_options(problems) do
    Enum.map(problems, fn problem ->
      {"#{problem.grade} · #{problem.title}", problem.id}
    end)
  end

  defp post_visibility_options do
    [{"Public", "public"}, {"Friends only", "friends"}]
  end

  defp ascent_visibility_options do
    post_visibility_options() ++ [{"Private", "private"}]
  end

  defp default_ascent_attrs do
    %{climbed_at: format_datetime_local(DateTime.utc_now(:second))}
  end

  defp default_session_attrs do
    %{
      started_at: format_datetime_local(DateTime.utc_now(:second)),
      visibility: "public",
      ascents: [%{boulder_problem_id: nil}]
    }
  end

  defp session_attrs_and_rows(socket, session_params, show_route_errors?) do
    session_params = normalize_params_map(session_params)
    ascent_params = normalize_params_map(Map.get(session_params, "ascents", %{}))

    rows =
      Enum.map(socket.assigns.session_row_order, fn row_id ->
        row_params =
          ascent_params
          |> Map.get(Integer.to_string(row_id), %{})
          |> normalize_params_map()

        route_id = Map.get(row_params, "boulder_problem_id")
        session_row(row_id, route_id, show_route_errors? && blank?(route_id))
      end)

    attrs =
      session_params
      |> Map.drop(["image_object_key", :image_object_key])
      |> Map.put(
        "ascents",
        Enum.map(rows, &%{"boulder_problem_id" => &1.boulder_problem_id})
      )

    {attrs, rows}
  end

  defp session_row(id, route_id \\ nil, invalid? \\ false) do
    %{
      id: id,
      boulder_problem_id: route_id,
      errors: if(invalid?, do: ["can't be blank"], else: [])
    }
  end

  defp session_row_number(row_order, row_id) do
    case Enum.find_index(row_order, &(&1 == row_id)) do
      nil -> 1
      index -> index + 1
    end
  end

  defp ordered_session_rows(socket) do
    Enum.map(socket.assigns.session_row_order, &Map.fetch!(socket.assigns.session_rows_by_id, &1))
  end

  defp session_ascent_errors(form) do
    form[:ascents].errors
    |> Enum.map(fn {message, options} ->
      Gettext.dgettext(AscentsWeb.Gettext, "errors", message, options)
    end)
  end

  defp ensure_composer_authorized(socket) do
    gym = Gyms.get_gym!(socket.assigns.gym.id)

    if Gyms.can_post_in_gym?(socket.assigns.current_scope, gym) do
      {:ok,
       socket
       |> assign(:gym, gym)
       |> assign(:membership, Gyms.get_membership(socket.assigns.current_scope, gym))}
    else
      {:error, assign_gym_state(socket, gym)}
    end
  end

  defp deny_composer_action(socket) do
    socket
    |> reset_post_modal()
    |> put_flash(:error, @composer_auth_error)
  end

  defp normalize_params_map(params) when is_map(params), do: params
  defp normalize_params_map(_params), do: %{}

  defp session_route_target?(%{"_target" => target}) when is_list(target) do
    Enum.take(target, 2) == ["session", "ascents"]
  end

  defp session_route_target?(_params), do: false

  defp blank?(value), do: is_nil(value) or (is_binary(value) and String.trim(value) == "")

  defp format_datetime_local(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0, 16)
  end
end
