ExUnit.start()
{:ok, _pid} = Ascents.Media.TestStorage.start_link([])
Ecto.Adapters.SQL.Sandbox.mode(Ascents.Repo, :manual)
