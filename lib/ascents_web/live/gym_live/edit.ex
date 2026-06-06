defmodule AscentsWeb.GymLive.Edit do
  use AscentsWeb, :live_view

  alias Ascents.Gyms
  alias AscentsWeb.UserAuth

  def mount(%{"slug" => slug}, session, socket) do
    current_scope = UserAuth.current_scope_from_session(session)
    gym = Gyms.get_gym_by_slug!(slug)

    if Gyms.can_update_gym?(current_scope, gym) do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign(:gym, gym)
       |> assign_form(Gyms.change_gym(gym))}
    else
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> put_flash(:error, "You are not allowed to edit this gym.")
       |> push_navigate(to: ~p"/gyms/#{gym.slug}")}
    end
  end

  def handle_event("validate", %{"gym" => gym_params}, socket) do
    changeset =
      socket.assigns.gym
      |> Gyms.change_gym(gym_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"gym" => gym_params}, socket) do
    case Gyms.update_gym(socket.assigns.current_scope, socket.assigns.gym, gym_params) do
      {:ok, gym} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gym settings updated.")
         |> push_navigate(to: ~p"/gyms/#{gym.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not allowed to edit this gym.")
         |> push_navigate(to: ~p"/gyms/#{socket.assigns.gym.slug}")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <section class="chalk-panel relative overflow-hidden rounded-lg border border-ascents-line p-6 sm:p-8">
          <.header>
            Gym Settings
            <:subtitle>Update community metadata. Slugs are generated and not editable.</:subtitle>
          </.header>

          <.form for={@form} id="gym-settings-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Gym name" required />
            <.input field={@form[:location]} type="text" label="Location" />
            <.input
              field={@form[:grade_scale]}
              type="select"
              label="Bouldering grade scale"
              options={grade_scale_options()}
            />
            <.input field={@form[:description]} type="textarea" label="Description" />

            <div class="flex flex-wrap gap-3">
              <.button variant="primary" phx-disable-with="Saving...">
                <.icon name="hero-check" class="size-4" /> Save settings
              </.button>
              <.button navigate={~p"/gyms/#{@gym.slug}"} variant="secondary">Cancel</.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp grade_scale_options do
    [{"V scale", "v_scale"}, {"French bouldering", "french"}]
  end
end
