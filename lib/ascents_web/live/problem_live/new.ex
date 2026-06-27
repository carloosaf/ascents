defmodule AscentsWeb.ProblemLive.New do
  use AscentsWeb, :live_view

  alias Ascents.Media
  alias Ascents.Routes, as: ClimbingRoutes
  alias Ascents.Routes.BoulderProblem
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)

    case ClimbingRoutes.get_management_gym(current_scope, slug) do
      {:ok, gym} ->
        {:ok,
         socket
         |> assign(:current_scope, current_scope)
         |> assign(:gym, gym)
         |> allow_upload(:image,
           accept: ~w(.jpg .jpeg .png .webp image/jpeg image/png image/webp),
           max_entries: 1,
           max_file_size: Media.max_file_size()
         )
         |> assign_form(ClimbingRoutes.change_boulder_problem(gym, %BoulderProblem{}))}

      {:error, :unauthorized, gym} ->
        {:ok,
         socket
         |> assign(:current_scope, current_scope)
         |> put_flash(:error, "You are not allowed to create routes for this gym.")
         |> push_navigate(to: ~p"/gyms/#{gym.slug}")}
    end
  end

  def handle_event("validate", %{"boulder_problem" => problem_params}, socket) do
    changeset =
      socket.assigns.gym
      |> ClimbingRoutes.change_boulder_problem(%BoulderProblem{}, problem_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"boulder_problem" => problem_params}, socket) do
    case put_uploaded_image(socket, problem_params, :problem) do
      {:ok, problem_params} ->
        case ClimbingRoutes.create_boulder_problem(
               socket.assigns.current_scope,
               socket.assigns.gym,
               problem_params
             ) do
          {:ok, _problem} ->
            {:noreply,
             socket
             |> put_flash(:info, "Boulder problem created.")
             |> push_navigate(to: ~p"/gyms/#{socket.assigns.gym.slug}/problems")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_form(socket, changeset)}

          {:error, :unauthorized} ->
            {:noreply,
             socket
             |> put_flash(:error, "You are not allowed to create routes for this gym.")
             |> push_navigate(to: ~p"/gyms/#{socket.assigns.gym.slug}")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <.header>
            New Boulder Problem
            <:subtitle>Add an active route for {@gym.name}.</:subtitle>
          </.header>

          <.form for={@form} id="problem-new-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input
              field={@form[:grade]}
              type="select"
              label="Grade"
              options={ClimbingRoutes.grade_options(@gym)}
            />
            <.input field={@form[:color]} type="text" label="Hold color" required />
            <.input field={@form[:description]} type="textarea" label="Description" />
            <.image_upload_input
              id="route-new-image-upload"
              upload={@uploads.image}
              label="Route image"
              help="Take a photo or choose a JPG, PNG, or WebP up to 5 MB."
            />

            <div class="flex flex-wrap gap-3">
              <.button variant="primary" phx-disable-with="Creating...">
                <.icon name="hero-plus" class="size-4" /> Create route
              </.button>
              <.button navigate={~p"/gyms/#{@gym.slug}/problems"} variant="secondary">
                Cancel
              </.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp put_uploaded_image(socket, attrs, owner) do
    case consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
           result = Media.upload_image(owner, path, entry.client_name, entry.client_type)
           {:ok, result}
         end) do
      [] -> {:ok, attrs}
      [{:ok, key}] -> {:ok, Map.put(attrs, "image_object_key", key)}
      [{:error, reason}] -> {:error, Media.upload_error_message(reason)}
    end
  end
end
