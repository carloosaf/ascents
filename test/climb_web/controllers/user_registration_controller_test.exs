defmodule ClimbWeb.UserRegistrationControllerTest do
  use ClimbWeb.ConnCase, async: true

  import Climb.AccountsFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#registration-form") |> Enum.any?()
      assert LazyHTML.text(document) =~ "Join Climb"
      assert document |> LazyHTML.query("a[href='/users/log-in']") |> Enum.any?()
      assert document |> LazyHTML.query("a[href='/users/register']") |> Enum.any?()
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account but does not log in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(email: email)
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"

      assert conn.assigns.flash["info"] =~
               ~r/An email was sent to .*, please access it to confirm your account/
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => "with spaces"}
        })

      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#registration-form") |> Enum.any?()
      assert LazyHTML.text(document) =~ "must have the @ sign and no spaces"
    end
  end
end
