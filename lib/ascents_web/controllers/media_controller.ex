defmodule AscentsWeb.MediaController do
  use AscentsWeb, :controller

  alias Ascents.Media

  def show(conn, %{"token" => token}) do
    case Media.get_authorized_object(conn.assigns.current_scope, token) do
      {:ok, body, content_type} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "private, max-age=300")
        |> send_resp(200, body)

      {:error, :not_found} ->
        send_resp(conn, 404, "Not found")
    end
  end
end
