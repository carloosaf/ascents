defmodule Ascents.Media.S3Storage do
  @moduledoc false

  alias ExAws.S3

  def put_object(key, body, content_type, config) do
    put_object_once(key, body, content_type, config)
    |> maybe_create_bucket_and_retry(key, body, content_type, config)
  end

  def get_object(key, config) do
    config
    |> bucket()
    |> S3.get_object(key)
    |> ExAws.request(ex_aws_options(config))
    |> case do
      {:ok, %{body: body, headers: headers}} ->
        {:ok, body, response_content_type(headers)}

      {:error, {:http_error, 404, _body}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, normalize_error(reason)}
    end
  end

  def delete_object(key, config) do
    config
    |> bucket()
    |> S3.delete_object(key)
    |> ExAws.request(ex_aws_options(config))
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  defp put_object_once(key, body, content_type, config) do
    config
    |> bucket()
    |> S3.put_object(key, body, content_type: content_type)
    |> ExAws.request(ex_aws_options(config))
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  defp maybe_create_bucket_and_retry({:error, :missing_bucket}, key, body, content_type, config) do
    if Keyword.get(config, :create_bucket_on_upload, false) do
      with :ok <- create_bucket(config) do
        put_object_once(key, body, content_type, config)
      end
    else
      {:error, :missing_bucket}
    end
  end

  defp maybe_create_bucket_and_retry(result, _key, _body, _content_type, _config), do: result

  defp create_bucket(config) do
    config
    |> bucket()
    |> S3.put_bucket(Keyword.fetch!(config, :region))
    |> ExAws.request(ex_aws_options(config))
    |> case do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, normalize_error(reason)}
    end
  end

  defp ex_aws_options(config) do
    uri = URI.parse(Keyword.fetch!(config, :endpoint))

    [
      scheme: "#{uri.scheme}://",
      host: uri.host,
      port: uri.port,
      region: Keyword.fetch!(config, :region),
      access_key_id: Keyword.fetch!(config, :access_key_id),
      secret_access_key: Keyword.fetch!(config, :secret_access_key)
    ]
  end

  defp bucket(config), do: Keyword.fetch!(config, :bucket)

  defp normalize_error({:http_error, 404, %{body: body}}) when is_binary(body) do
    if String.contains?(body, "<Code>NoSuchBucket</Code>") do
      :missing_bucket
    else
      :not_found
    end
  end

  defp normalize_error(reason), do: reason

  defp response_content_type(headers) do
    headers
    |> Enum.find_value("application/octet-stream", fn
      {"content-type", value} -> value
      {"Content-Type", value} -> value
      _header -> nil
    end)
  end
end
