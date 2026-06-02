defmodule AscentsWeb.ProfileLive.Edit do
  use AscentsWeb, :live_view

  alias Ascents.Accounts
  alias Ascents.Accounts.Scope

  def mount(_params, session, socket) do
    current_scope =
      session
      |> Map.get("user_token")
      |> scope_from_token()

    if current_scope do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> assign_profile_form()}
    else
      {:ok, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :profile_form, form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_scope, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully.")
         |> push_navigate(to: ~p"/u/#{user.username}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl rounded-lg border border-ascents-line bg-ascents-panel p-6 shadow-2xl shadow-black/20">
        <div class="text-center">
          <.header>
            Profile Settings
            <:subtitle>Manage the member profile other logged-in climbers can view.</:subtitle>
          </.header>
        </div>

        <.form
          for={@profile_form}
          id="profile-settings-form"
          phx-change="validate"
          phx-submit="save"
        >
          <.input
            field={@profile_form[:username]}
            type="text"
            label="Username"
            autocomplete="username"
            spellcheck="false"
            required
          />

          <.input
            field={@profile_form[:display_name]}
            type="text"
            label="Display name"
            autocomplete="name"
          />

          <.input field={@profile_form[:bio]} type="textarea" label="Bio" />

          <div class="flex flex-wrap gap-3">
            <.button variant="primary" phx-disable-with="Saving...">Save Profile</.button>
            <.link
              href={~p"/users/settings"}
              class="inline-flex items-center rounded-md border border-ascents-line px-4 py-2 text-sm font-bold text-ascents-chalk transition hover:border-ascents-action hover:text-white"
            >
              Account Settings
            </.link>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp assign_profile_form(socket) do
    assign(
      socket,
      :profile_form,
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile()
      |> to_form()
    )
  end

  defp scope_from_token(nil), do: Scope.for_user(nil)

  defp scope_from_token(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> Scope.for_user(user)
      nil -> Scope.for_user(nil)
    end
  end
end
