defmodule Ascents.Repo do
  use Ecto.Repo,
    otp_app: :ascents,
    adapter: Ecto.Adapters.Postgres
end
