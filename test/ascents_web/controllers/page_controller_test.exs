defmodule AscentsWeb.PageControllerTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures

  test "GET / renders the public homepage for anonymous users", %{conn: conn} do
    conn = get(conn, ~p"/")

    document =
      conn
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#home-page") |> Enum.any?()
    assert document |> LazyHTML.query("#home-feed-1") |> Enum.any?()
    assert document |> LazyHTML.query("#home-route-1") |> Enum.any?()
  end

  test "GET / redirects authenticated users to their feed", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/feed"
  end
end
