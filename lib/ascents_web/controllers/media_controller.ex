defmodule AscentsWeb.MediaController do
  use AscentsWeb, :controller

  alias Ascents.Media

  def show(conn, %{"token" => token}) do
    case Media.get_authorized_object(conn.assigns.current_scope, token) do
      {:ok, body, content_type, cache_policy} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", cache_control(cache_policy))
        |> send_resp(200, body)

      {:error, :not_found} ->
        send_resp(conn, 404, "Not found")
    end
  end

  defp cache_control(:restricted_post), do: "private, no-store, max-age=0, must-revalidate"
  defp cache_control(:public_post), do: "public, no-cache, max-age=0, must-revalidate"
  defp cache_control(:default), do: "private, max-age=300"
end
