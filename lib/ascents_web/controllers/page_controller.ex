defmodule AscentsWeb.PageController do
  use AscentsWeb, :controller

  def home(%{assigns: %{current_scope: %{user: user}}} = conn, _params) when not is_nil(user) do
    redirect(conn, to: ~p"/feed")
  end

  def home(conn, _params) do
    render(conn, :home)
  end
end
