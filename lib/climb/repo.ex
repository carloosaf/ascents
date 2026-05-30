defmodule Climb.Repo do
  use Ecto.Repo,
    otp_app: :climb,
    adapter: Ecto.Adapters.Postgres
end
