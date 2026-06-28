defmodule AscentsWeb.LayoutsTest do
  use ExUnit.Case, async: true
  use AscentsWeb, :html

  import Phoenix.LiveViewTest

  test "app layout renders multiple modal slot entries as app shell siblings above chrome" do
    document =
      (&app_with_multiple_modals/1)
      |> render_component(%{})
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#app-shell > main.ascents-wall") |> Enum.any?()
    assert document |> LazyHTML.query("#app-shell > #app-mobile-tabbar") |> Enum.any?()

    assert document
           |> LazyHTML.query("#app-shell > #app-mobile-tabbar + #first-modal.fixed.z-50")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#app-shell > #first-modal + #second-modal.fixed.z-50")
           |> Enum.any?()

    refute document |> LazyHTML.query("main.ascents-wall #first-modal") |> Enum.any?()
    refute document |> LazyHTML.query("main.ascents-wall #second-modal") |> Enum.any?()
  end

  defp app_with_multiple_modals(assigns) do
    ~H"""
    <Layouts.app flash={%{}}>
      <section id="layout-test-page">Page content</section>

      <:modal>
        <div id="first-modal" class="fixed inset-0 z-50">First modal</div>
      </:modal>
      <:modal>
        <div id="second-modal" class="fixed inset-0 z-50">Second modal</div>
      </:modal>
    </Layouts.app>
    """
  end
end
