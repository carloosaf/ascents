defmodule AscentsWeb.ProductComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "grade badge renders a stable component marker" do
    document =
      (&AscentsWeb.ProductComponents.grade_badge/1)
      |> render_component(%{grade: "V5"})
      |> LazyHTML.from_fragment()

    badge = LazyHTML.query(document, "[data-component='grade-badge']")

    assert Enum.any?(badge)
    assert LazyHTML.text(badge) =~ "V5"
  end

  test "feed item renders social actions and optional bold grade" do
    document =
      (&AscentsWeb.ProductComponents.feed_item/1)
      |> render_component(%{
        id: "component-test-feed",
        author: "Mara Silva",
        gym: "Bloc District",
        time: "12 min ago",
        body: "Sent the blue cave project.",
        grade: "V5",
        comments: 9,
        reaction_count: 42
      })
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#component-test-feed") |> Enum.any?()
    assert document |> LazyHTML.query("[data-component='grade-badge']") |> Enum.any?()
    assert LazyHTML.text(document) =~ "Bloc District"
  end
end
