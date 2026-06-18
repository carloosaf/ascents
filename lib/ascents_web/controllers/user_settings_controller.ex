defmodule AscentsWeb.UserSettingsController do
  use AscentsWeb, :controller

  alias Ascents.Accounts
  alias AscentsWeb.UserAuth

  import AscentsWeb.UserAuth, only: [require_sudo_mode: 2]

  plug :require_sudo_mode
  plug :assign_settings_forms

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      changeset ->
        render(conn, :edit, email_form: Phoenix.Component.to_form(%{changeset | action: :insert}))
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _}} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_form: Phoenix.Component.to_form(changeset))
    end
  end

  def update(conn, %{"action" => "update_appearance"} = params) do
    %{"user" => user_params} = params

    case Accounts.update_user_appearance(conn.assigns.current_scope, user_params) do
      {:ok, user} ->
        current_scope = %{conn.assigns.current_scope | user: user}

        conn
        |> assign(:current_scope, current_scope)
        |> put_flash(:info, "Appearance updated.")
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit, appearance_form: Phoenix.Component.to_form(changeset))
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp assign_settings_forms(conn, _opts) do
    user = conn.assigns.current_scope.user

    conn
    |> assign(:email_form, user |> Accounts.change_user_email() |> Phoenix.Component.to_form())
    |> assign(
      :appearance_form,
      user |> Accounts.change_user_appearance() |> Phoenix.Component.to_form()
    )
    |> assign(
      :password_form,
      user |> Accounts.change_user_password() |> Phoenix.Component.to_form()
    )
  end
end
