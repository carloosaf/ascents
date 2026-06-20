defmodule AscentsWeb.UserRegistrationController do
  use AscentsWeb, :controller

  alias Ascents.Accounts
  alias Ascents.Accounts.User

  def new(conn, _params) do
    form =
      %User{}
      |> Accounts.change_user_registration()
      |> Phoenix.Component.to_form()

    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Account created successfully.")
        |> AscentsWeb.UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, form: Phoenix.Component.to_form(changeset))
    end
  end
end
