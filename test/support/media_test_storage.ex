defmodule Ascents.Media.TestStorage do
  @moduledoc false

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_object(key, body, content_type, _config) do
    Agent.update(__MODULE__, &Map.put(&1, key, {body, content_type}))
  end

  def get_object(key, _config) do
    case Agent.get(__MODULE__, &Map.get(&1, key)) do
      {body, content_type} -> {:ok, body, content_type}
      nil -> {:error, :not_found}
    end
  end

  def delete_object(key, _config) do
    Agent.update(__MODULE__, &Map.delete(&1, key))
  end

  def objects do
    Agent.get(__MODULE__, & &1)
  end

  def reset! do
    Agent.update(__MODULE__, fn _objects -> %{} end)
  end
end
