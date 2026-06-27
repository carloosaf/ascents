defmodule AscentsWeb.PageControllerTest do
  use AscentsWeb.ConnCase, async: true

  import Ascents.AccountsFixtures

  test "GET / explains Ascents and offers anonymous visitor actions", %{conn: conn} do
    conn = get(conn, ~p"/")

    document =
      conn
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#home-page") |> Enum.any?()
    assert document |> LazyHTML.query("#home-hero.text-center") |> Enum.any?()
    assert document |> LazyHTML.query("#home-purpose") |> Enum.any?()
    assert document |> LazyHTML.query("#home-product-loop") |> Enum.any?()
    assert document |> LazyHTML.query("#home-step-gym") |> Enum.any?()
    assert document |> LazyHTML.query("#home-step-routes") |> Enum.any?()
    assert document |> LazyHTML.query("#home-step-sessions") |> Enum.any?()
    assert document |> LazyHTML.query("#home-step-friends") |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-register-cta[href='/users/register']")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-login-cta[href='/users/log-in']")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-browse-gyms-cta[href='/gyms']")
           |> Enum.any?()

    refute document |> LazyHTML.query("#home-member-actions") |> Enum.any?()
    refute document |> LazyHTML.query("#home-action-panel") |> Enum.any?()
    refute document |> LazyHTML.query("#app-sidebar") |> Enum.any?()
    refute document |> LazyHTML.query("#app-mobile-tabbar") |> Enum.any?()
  end

  test "GET / renders relevant actions for authenticated users", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    document =
      conn
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#home-authenticated-intro") |> Enum.any?()
    assert document |> LazyHTML.query("#home-member-actions") |> Enum.any?()
    assert document |> LazyHTML.query("#home-hero.text-center") |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-member-feed-link[href='/feed']")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-member-gyms-link[href='/gyms']")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-member-stats-link[href='/users/stats']")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#home-member-profile-link[href='/u/#{user.username}']")
           |> Enum.any?()

    refute document |> LazyHTML.query("#home-anonymous-actions") |> Enum.any?()
    refute document |> LazyHTML.query("#home-action-panel") |> Enum.any?()
    refute document |> LazyHTML.query("#app-sidebar") |> Enum.any?()
    refute document |> LazyHTML.query("#app-mobile-tabbar") |> Enum.any?()
  end
end
