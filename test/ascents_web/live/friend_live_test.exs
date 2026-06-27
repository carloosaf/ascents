defmodule AscentsWeb.FriendLiveTest do
  use AscentsWeb.ConnCase

  import Ascents.AccountsFixtures
  import Ascents.FriendsFixtures
  import Phoenix.LiveViewTest

  alias Ascents.Friends

  describe "index" do
    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/friends")
    end

    test "renders stable empty states for a new user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/friends")

      assert has_element?(view, "#friends-page")
      assert has_element?(view, "#friend-search-form")
      assert has_element?(view, "#friend-search-prompt")
      assert has_element?(view, "#incoming-requests-empty")
      assert has_element?(view, "#outgoing-requests-empty")
      assert has_element?(view, "#accepted-friends-empty")
    end

    test "shows incoming, outgoing, and accepted relationship lists with profile links", %{
      conn: conn
    } do
      current_user = user_fixture(username: "list_owner")
      incoming_user = user_fixture(username: "incoming_climber")
      outgoing_user = user_fixture(username: "outgoing_climber")
      accepted_user = user_fixture(username: "accepted_climber")

      incoming =
        friendship_fixture(requester: incoming_user, recipient: current_user)

      outgoing =
        friendship_fixture(requester: current_user, recipient: outgoing_user)

      accepted_friendship_fixture(requester: accepted_user, recipient: current_user)

      conn = log_in_user(conn, current_user)
      {:ok, view, _html} = live(conn, ~p"/friends")

      refute has_element?(view, "#incoming-requests-empty")
      refute has_element?(view, "#outgoing-requests-empty")
      refute has_element?(view, "#accepted-friends-empty")

      assert has_element?(
               view,
               "#incoming-request-profile-#{incoming.id}[href='/u/#{incoming_user.username}']"
             )

      assert has_element?(
               view,
               "#outgoing-request-profile-#{outgoing.id}[href='/u/#{outgoing_user.username}']"
             )

      assert has_element?(
               view,
               "#accepted-friend-profile-#{accepted_user.id}[href='/u/#{accepted_user.username}']"
             )
    end

    test "searches profiles, excludes the current user, and shows relationship states", %{
      conn: conn
    } do
      current_user = user_fixture(username: "crew_current")
      incoming_user = user_fixture(username: "crew_incoming")
      outgoing_user = user_fixture(username: "crew_outgoing")
      accepted_user = user_fixture(username: "crew_accepted")
      stranger = user_fixture(username: "crew_stranger")

      friendship_fixture(requester: incoming_user, recipient: current_user)
      friendship_fixture(requester: current_user, recipient: outgoing_user)
      accepted_friendship_fixture(requester: accepted_user, recipient: current_user)

      conn = log_in_user(conn, current_user)
      {:ok, view, _html} = live(conn, ~p"/friends")

      view
      |> form("#friend-search-form", search: %{query: "crew"})
      |> render_change()

      refute has_element?(view, "#friend-search-prompt")
      refute has_element?(view, "#friend-search-empty")
      refute has_element?(view, "#friend-search-profile-#{current_user.id}")

      for user <- [incoming_user, outgoing_user, accepted_user, stranger] do
        assert has_element?(
                 view,
                 "#friend-search-profile-#{user.id}[href='/u/#{user.username}']"
               )
      end

      assert has_element?(
               view,
               "#friend-search-state-#{incoming_user.id}[data-state='incoming_pending']"
             )

      assert has_element?(
               view,
               "#friend-search-state-#{outgoing_user.id}[data-state='outgoing_pending']"
             )

      assert has_element?(
               view,
               "#friend-search-state-#{accepted_user.id}[data-state='friends']"
             )

      assert has_element?(
               view,
               "#friend-search-state-#{stranger.id}[data-state='none']"
             )

      assert has_element?(view, "#friend-search-send-#{stranger.id}")
      refute has_element?(view, "#friend-search-send-#{incoming_user.id}")
      refute has_element?(view, "#friend-search-send-#{outgoing_user.id}")
      refute has_element?(view, "#friend-search-send-#{accepted_user.id}")
    end

    test "shows a searched empty state when no profiles match", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      {:ok, view, _html} = live(conn, ~p"/friends")

      view
      |> form("#friend-search-form", search: %{query: "no_such_climber"})
      |> render_change()

      assert has_element?(view, "#friend-search-empty")
      refute has_element?(view, "#friend-search-prompt")
    end

    test "sends a request from a search result and refreshes relationship state", %{conn: conn} do
      current_user = user_fixture(username: "request_owner")
      recipient = user_fixture(username: "request_target")
      scope = user_scope_fixture(current_user)
      conn = log_in_user(conn, current_user)
      {:ok, view, _html} = live(conn, ~p"/friends")

      view
      |> form("#friend-search-form", search: %{query: recipient.username})
      |> render_change()

      view
      |> element("#friend-search-send-#{recipient.id}")
      |> render_click()

      assert Friends.relationship_state(scope, recipient) == :outgoing_pending
      assert has_element?(view, "#flash-info")
      refute has_element?(view, "#friend-search-send-#{recipient.id}")

      assert has_element?(
               view,
               "#friend-search-state-#{recipient.id}[data-state='outgoing_pending']"
             )

      [friendship] = Friends.list_outgoing_requests(scope)

      assert has_element?(
               view,
               "#outgoing-request-profile-#{friendship.id}[href='/u/#{recipient.username}']"
             )
    end

    test "handles a forged self-request without creating a relationship", %{conn: conn} do
      current_user = user_fixture(username: "self_request_owner")
      scope = user_scope_fixture(current_user)
      conn = log_in_user(conn, current_user)
      {:ok, view, _html} = live(conn, ~p"/friends")

      render_click(view, "send-request", %{"user-id" => Integer.to_string(current_user.id)})

      assert has_element?(view, "#flash-error")
      assert Friends.list_outgoing_requests(scope) == []
      assert Friends.relationship_state(scope, current_user) == :self
    end

    test "rejects a forged valid user ID that was not in the current search results", %{
      conn: conn
    } do
      current_user = user_fixture(username: "forged_request_owner")
      searched_user = user_fixture(username: "searched_request_target")
      unsearched_user = user_fixture(username: "forged_hidden_target")
      scope = user_scope_fixture(current_user)
      conn = log_in_user(conn, current_user)
      {:ok, view, _html} = live(conn, ~p"/friends")

      view
      |> form("#friend-search-form", search: %{query: searched_user.username})
      |> render_change()

      assert has_element?(view, "#friend-search-send-#{searched_user.id}")
      refute has_element?(view, "#friend-search-profile-#{unsearched_user.id}")

      render_click(view, "send-request", %{"user-id" => Integer.to_string(unsearched_user.id)})

      assert has_element?(view, "#flash-error")
      assert Friends.list_outgoing_requests(scope) == []
      assert Friends.relationship_state(scope, unsearched_user) == :none
    end
  end
end
