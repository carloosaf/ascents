defmodule Ascents.MediaTest do
  use Ascents.DataCase

  import Ascents.AccountsFixtures
  import Ascents.GymsFixtures
  import Ascents.RoutesFixtures

  alias Ascents.Media
  alias Ascents.Media.TestStorage

  setup do
    TestStorage.reset!()
    :ok
  end

  test "uploads validated images under scoped object keys" do
    gym = gym_fixture()
    problem = boulder_problem_fixture(gym: gym)
    path = fixture_path("test-image.jpg")

    assert {:ok, key} = Media.upload_image({:problem, problem}, path, "problem.jpg", "image/jpeg")
    assert key =~ ~r/^problems\/#{problem.id}\//
    assert {:ok, "test image bytes\n", "image/jpeg"} = Media.get_object(key)
  end

  test "rejects unsupported image uploads" do
    gym = gym_fixture()

    assert {:error, :invalid_extension} =
             Media.upload_image(
               {:gym, gym},
               fixture_path("test-image.jpg"),
               "gym.gif",
               "image/jpeg"
             )

    assert {:error, :invalid_content_type} =
             Media.upload_image(
               {:gym, gym},
               fixture_path("test-image.jpg"),
               "gym.jpg",
               "image/gif"
             )
  end

  test "generates and verifies signed media URLs" do
    assert url = Media.signed_url("gyms/1/wall.jpg")
    token = url |> URI.parse() |> Map.fetch!(:path) |> Path.basename()

    assert Media.verify_token(token) == {:ok, "gyms/1/wall.jpg"}
  end

  test "checks user avatar authorization against authenticated scopes" do
    user = user_fixture()

    assert Media.authorized?(user_scope_fixture(user), {:user, user})
    refute Media.authorized?(nil, {:user, user})
  end

  defp fixture_path(name) do
    Path.expand("../support/fixtures/files/#{name}", __DIR__)
  end
end
