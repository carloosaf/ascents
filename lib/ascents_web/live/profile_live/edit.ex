defmodule AscentsWeb.ProfileLive.Edit do
  use AscentsWeb, :live_view

  alias Ascents.Accounts
  alias Ascents.Accounts.Scope
  alias Ascents.Media

  def mount(_params, session, socket) do
    current_scope =
      session
      |> Map.get("user_token")
      |> scope_from_token()

    if current_scope do
      {:ok,
       socket
       |> assign(:current_scope, current_scope)
       |> allow_upload(:avatar,
         accept: ~w(.jpg .jpeg .png .webp),
         max_entries: 1,
         max_file_size: Media.max_file_size()
       )
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
    case put_uploaded_avatar(socket, user_params) do
      {:ok, user_params} ->
        case Accounts.update_user_profile(socket.assigns.current_scope, user_params) do
          {:ok, user} ->
            {:noreply,
             socket
             |> put_flash(:info, "Profile updated successfully.")
             |> push_navigate(to: ~p"/u/#{user.username}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :profile_form, to_form(changeset))}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
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

          <input
            type="hidden"
            name="user[avatar_object_key]"
            value={@profile_form[:avatar_object_key].value}
          />
          <div class="mb-4">
            <label for={@uploads.avatar.ref} class="block">
              <span class="mb-1.5 block text-sm font-semibold text-ascents-chalk">
                Avatar
              </span>
              <.live_file_input
                upload={@uploads.avatar}
                class="block w-full rounded-md border border-ascents-line bg-ascents-panel-deep px-3 py-2.5 text-sm text-ascents-chalk file:mr-3 file:rounded-md file:border-0 file:bg-ascents-action file:px-3 file:py-1.5 file:text-sm file:font-bold file:text-ascents-action-content hover:file:bg-ascents-action-hover"
              />
            </label>
            <p class="mt-1.5 text-xs text-ascents-muted">
              JPG, PNG, or WebP up to 5 MB.
            </p>
            <p
              :for={err <- upload_errors(@uploads.avatar)}
              class="mt-1.5 text-sm text-ascents-danger-hover"
            >
              {upload_error_message(err)}
            </p>
          </div>

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

  defp put_uploaded_avatar(socket, attrs) do
    owner = {:user, socket.assigns.current_scope.user}

    case consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
           result = Media.upload_image(owner, path, entry.client_name, entry.client_type)
           {:ok, result}
         end) do
      [] -> {:ok, attrs}
      [{:ok, key}] -> {:ok, Map.put(attrs, "avatar_object_key", key)}
      [{:error, reason}] -> {:error, upload_error_message(reason)}
    end
  end

  defp upload_error_message(:too_large), do: "Choose an image up to 5 MB."
  defp upload_error_message(:not_accepted), do: "Choose a JPG, PNG, or WebP image."
  defp upload_error_message(:invalid_content_type), do: "Choose a JPG, PNG, or WebP image."
  defp upload_error_message(:invalid_extension), do: "Choose a JPG, PNG, or WebP image."
  defp upload_error_message(:missing_bucket), do: "Storage is not ready. Check the MinIO bucket."
  defp upload_error_message(_reason), do: "The image could not be uploaded."

  defp scope_from_token(nil), do: Scope.for_user(nil)

  defp scope_from_token(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> Scope.for_user(user)
      nil -> Scope.for_user(nil)
    end
  end
end
