defmodule AscentsWeb.PageController do
  use AscentsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
