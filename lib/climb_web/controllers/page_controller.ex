defmodule ClimbWeb.PageController do
  use ClimbWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
