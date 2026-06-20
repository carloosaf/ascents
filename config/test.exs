import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
test_database_url =
  System.fetch_env!("TEST_DATABASE_URL")
  |> URI.parse()
  |> Map.update!(:path, &"#{&1}#{System.get_env("MIX_TEST_PARTITION")}")
  |> URI.to_string()

test_database_params = URI.decode_query(URI.parse(test_database_url).query || "")

config :ascents, Ascents.Repo,
  url: test_database_url,
  ssl: test_database_params["sslmode"] in ~w(require verify-ca verify-full),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ascents, AscentsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gDARj6d0RYHdPIPyjCc21SVxmTA1xbBpOM0xrLO0ZrgVg/W3erKN8bMS4bvXbQeZ",
  server: false

config :ascents, Ascents.Mailer, adapter: Swoosh.Adapters.Test

config :ascents, Ascents.Media,
  storage: Ascents.Media.TestStorage,
  bucket: "ascents-test",
  endpoint: "http://localhost:9000",
  access_key_id: "test",
  secret_access_key: "test",
  region: "us-east-1"

config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
