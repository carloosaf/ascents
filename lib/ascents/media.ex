defmodule Ascents.Media do
  @moduledoc """
  Boundary for private image storage.
  """

  alias Ascents.Accounts.{Scope, User}
  alias Ascents.Feed
  alias Ascents.Feed.Post
  alias Ascents.Gyms.Gym
  alias Ascents.Repo
  alias Ascents.Routes.BoulderProblem

  @allowed_content_types ~w(image/jpeg image/png image/webp)
  @allowed_extensions ~w(.jpg .jpeg .png .webp)
  @max_file_size 5 * 1024 * 1024
  @signed_max_age_seconds 5 * 60

  @doc """
  Uploads a validated image and returns its private object key.
  """
  def upload_image(owner, source_path, client_name, content_type) do
    with :ok <- validate_image(source_path, client_name, content_type),
         {:ok, body} <- File.read(source_path),
         key <- object_key(owner, client_name),
         :ok <- storage().put_object(key, body, content_type, config()) do
      {:ok, key}
    end
  end

  @doc """
  Downloads a private object by key.
  """
  def get_object(object_key) when is_binary(object_key) do
    storage().get_object(object_key, config())
  end

  def get_object(_object_key), do: {:error, :not_found}

  @doc """
  Generates a short-lived application URL for a public-owner stored object.

  Post object keys must use the scope-aware `signed_url/2` function.
  """
  def signed_url("posts/" <> _post_object_key), do: nil

  def signed_url(object_key) when is_binary(object_key) and object_key != "" do
    token = Phoenix.Token.sign(AscentsWeb.Endpoint, signing_salt(), object_key)
    AscentsWeb.Endpoint.url() <> "/media/#{token}"
  end

  def signed_url(_object_key), do: nil

  @doc """
  Generates a short-lived, owner-bound URL after authorizing the current scope.

  Post tokens bind both the post and its current object key. The media endpoint
  rechecks the post visibility and binding before reading from storage.
  """
  def signed_url(scope, {:post, %Post{image_object_key: object_key} = post})
      when is_binary(object_key) and object_key != "" do
    if authorized?(scope, {:post, post}) do
      signed_url_for({:post, post.id, object_key})
    end
  end

  def signed_url(_scope, {:post, _post}), do: nil

  @doc """
  Verifies a signed media token.
  """
  def verify_token(token) when is_binary(token) do
    Phoenix.Token.verify(AscentsWeb.Endpoint, signing_salt(), token,
      max_age: @signed_max_age_seconds
    )
  end

  def verify_token(_token), do: {:error, :invalid}

  @doc """
  Resolves and downloads a token only when its current owner remains authorized.
  """
  def get_authorized_object(scope, token) do
    with {:ok, payload} <- verify_token(token),
         {:ok, object_key} <- authorized_object_key(scope, payload),
         {:ok, body, content_type} <- get_object(object_key) do
      {:ok, body, content_type}
    else
      {:error, _reason} -> {:error, :not_found}
    end
  end

  @doc """
  Returns true when the current scope can receive a signed URL for an owner image.
  """
  def authorized?(%Scope{user: %User{}}, {:user, %User{}}), do: true
  def authorized?(_scope, {:user, _user}), do: false

  def authorized?(_scope, {:gym, %Gym{}}), do: true
  def authorized?(_scope, {:problem, %BoulderProblem{}}), do: true
  def authorized?(scope, {:post, %Post{} = post}), do: Feed.can_view_post?(scope, post)
  def authorized?(_scope, _owner), do: false

  def allowed_content_types, do: @allowed_content_types
  def max_file_size, do: @max_file_size

  def upload_error_message(:too_large), do: "Choose an image up to 5 MB."
  def upload_error_message(:not_accepted), do: "Choose a JPG, PNG, or WebP image."
  def upload_error_message(:invalid_content_type), do: "Choose a JPG, PNG, or WebP image."
  def upload_error_message(:invalid_extension), do: "Choose a JPG, PNG, or WebP image."
  def upload_error_message(:missing_bucket), do: "Storage is not ready. Check the MinIO bucket."
  def upload_error_message(_reason), do: "The image could not be uploaded."

  defp validate_image(source_path, client_name, content_type) do
    cond do
      content_type not in @allowed_content_types ->
        {:error, :invalid_content_type}

      extension(client_name) not in @allowed_extensions ->
        {:error, :invalid_extension}

      file_size(source_path) > @max_file_size ->
        {:error, :too_large}

      true ->
        :ok
    end
  end

  defp object_key({:problem, %BoulderProblem{id: id}}, client_name),
    do: scoped_key("problems", id, client_name)

  defp object_key({:gym, %Gym{id: id}}, client_name), do: scoped_key("gyms", id, client_name)
  defp object_key({:post, %Post{id: id}}, client_name), do: scoped_key("posts", id, client_name)
  defp object_key({:user, %User{id: id}}, client_name), do: scoped_key("users", id, client_name)

  defp object_key(:problem, client_name), do: scoped_key("problems", "pending", client_name)
  defp object_key(:gym, client_name), do: scoped_key("gyms", "pending", client_name)
  defp object_key(:post, client_name), do: scoped_key("posts", "pending", client_name)
  defp object_key(:user, client_name), do: scoped_key("users", "pending", client_name)

  defp scoped_key(prefix, id, client_name) do
    "#{prefix}/#{id}/#{System.system_time(:millisecond)}-#{Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)}#{extension(client_name)}"
  end

  defp extension(client_name) when is_binary(client_name) do
    client_name
    |> Path.extname()
    |> String.downcase()
  end

  defp extension(_client_name), do: ""

  defp file_size(source_path) do
    case File.stat(source_path) do
      {:ok, %{size: size}} -> size
      {:error, _reason} -> @max_file_size + 1
    end
  end

  defp storage do
    Application.get_env(:ascents, __MODULE__, [])
    |> Keyword.get(:storage, Ascents.Media.S3Storage)
  end

  defp config do
    Application.fetch_env!(:ascents, __MODULE__)
  end

  defp signing_salt, do: "media object access"

  defp signed_url_for(payload) do
    token = Phoenix.Token.sign(AscentsWeb.Endpoint, signing_salt(), payload)
    AscentsWeb.Endpoint.url() <> "/media/#{token}"
  end

  defp authorized_object_key(scope, {:post, post_id, object_key})
       when is_integer(post_id) and is_binary(object_key) do
    case Repo.get(Post, post_id) do
      %Post{image_object_key: ^object_key} = post ->
        if authorized?(scope, {:post, post}) do
          {:ok, object_key}
        else
          {:error, :not_found}
        end

      _post ->
        {:error, :not_found}
    end
  end

  defp authorized_object_key(_scope, "posts/" <> _post_object_key),
    do: {:error, :not_found}

  defp authorized_object_key(_scope, object_key) when is_binary(object_key),
    do: {:ok, object_key}

  defp authorized_object_key(_scope, _payload), do: {:error, :not_found}
end
