defmodule AscentsWeb.MediaControllerTest do
  use AscentsWeb.ConnCase

  alias Ascents.Media
  alias Ascents.Media.TestStorage

  setup do
    TestStorage.reset!()
    :ok
  end

  test "serves signed private media objects", %{conn: conn} do
    :ok = TestStorage.put_object("gyms/1/wall.jpg", "image body", "image/jpeg", [])

    token =
      Media.signed_url("gyms/1/wall.jpg") |> URI.parse() |> Map.fetch!(:path) |> Path.basename()

    conn = get(conn, ~p"/media/#{token}")

    assert response(conn, 200) == "image body"
    assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
  end

  test "rejects invalid media tokens", %{conn: conn} do
    conn = get(conn, ~p"/media/not-a-token")

    assert response(conn, 403) == "Forbidden"
  end
end
