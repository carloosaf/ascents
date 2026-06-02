defmodule AscentsWeb.PageControllerTest do
  use AscentsWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    document =
      conn
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#home-page") |> Enum.any?()
    assert document |> LazyHTML.query("#home-feed-1") |> Enum.any?()
    assert document |> LazyHTML.query("#home-route-1") |> Enum.any?()
  end
end
