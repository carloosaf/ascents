defmodule AscentsWeb.MediaController do
  use AscentsWeb, :controller

  alias Ascents.Media

  def show(conn, %{"token" => token}) do
    with {:ok, object_key} <- Media.verify_token(token),
         {:ok, body, content_type} <- Media.get_object(object_key) do
      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "private, max-age=300")
      |> send_resp(200, body)
    else
      {:error, :not_found} ->
        send_resp(conn, 404, "Not found")

      {:error, _reason} ->
        send_resp(conn, 403, "Forbidden")
    end
  end
end
