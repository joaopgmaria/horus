import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

# Support both Docker (DATABASE_URL) and local development
database_url = System.get_env("DATABASE_URL")

if database_url do
  # Docker environment - parse DATABASE_URL and replace database name with test database
  # DATABASE_URL format: postgresql://user:pass@host:port/database
  test_url =
    String.replace(
      database_url,
      ~r{/[^/]+$},
      "/horus_test#{System.get_env("MIX_TEST_PARTITION")}"
    )

  config :horus, Horus.Repo,
    url: test_url,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
else
  # Local environment - use standard config
  config :horus, Horus.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "horus_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
end

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :horus, HorusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6vJ5r2dDxLUMu/cxwek3Z1ltc0fsQGk0KyFBFArTFuQJ8Mg4t/RFHE17g70/H/Qb",
  server: false

# In test we don't send emails
config :horus, Horus.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
