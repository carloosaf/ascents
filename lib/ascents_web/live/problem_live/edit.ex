defmodule AscentsWeb.ProblemLive.Edit do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias Ascents.Routes, as: ClimbingRoutes
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug, "id" => id}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)
    problem = ClimbingRoutes.get_boulder_problem!(gym, id)

    if Gyms.can_manage_routes?(current_scope, gym) do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:gym, gym)
       |> assign(:problem, problem)
       |> assign_form(ClimbingRoutes.change_boulder_problem(gym, problem))}
    else
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> put_flash(:error, "You are not allowed to edit routes for this gym.")
       |> push_navigate(to: ~p"/gyms/#{gym.slug}")}
    end
  end

  def handle_event("validate", %{"boulder_problem" => problem_params}, socket) do
    changeset =
      socket.assigns.gym
      |> ClimbingRoutes.change_boulder_problem(socket.assigns.problem, problem_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"boulder_problem" => problem_params}, socket) do
    case ClimbingRoutes.update_boulder_problem(
           socket.assigns.current_scope,
           socket.assigns.gym,
           socket.assigns.problem,
           problem_params
         ) do
      {:ok, _problem} ->
        {:noreply,
         socket
         |> put_flash(:info, "Boulder problem updated.")
         |> push_navigate(to: ~p"/gyms/#{socket.assigns.gym.slug}/problems")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not allowed to edit routes for this gym.")
         |> push_navigate(to: ~p"/gyms/#{socket.assigns.gym.slug}")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <.header>
            Edit Boulder Problem
            <:subtitle>Update route details for {@gym.name}.</:subtitle>
          </.header>

          <.form for={@form} id="problem-edit-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input
              field={@form[:grade]}
              type="select"
              label="Grade"
              options={ClimbingRoutes.grade_options(@gym)}
            />
            <.input field={@form[:color]} type="text" label="Hold color" required />
            <.input field={@form[:description]} type="textarea" label="Description" />
            <.input
              field={@form[:image_object_key]}
              type="text"
              label="Image object key"
              placeholder="Deferred until media uploads land"
            />

            <div class="flex flex-wrap gap-3">
              <.button variant="primary" phx-disable-with="Saving...">
                <.icon name="hero-check" class="size-4" /> Save route
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
end
