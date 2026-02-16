# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :horus,
  ecto_repos: [Horus.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :horus, HorusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: HorusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Horus.PubSub,
  live_view: [signing_salt: "z77a9RNY"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :horus, Horus.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Blueprint DSL Operators
# Configure which operators are enabled for this environment
# This allows testing operators in dev/test before promoting to production
config :horus, :blueprint_operators, [
  Horus.Blueprint.Operator.Presence
  # Add more operators here as they are implemented:
  # Horus.Blueprint.Operator.TypeCheck,
  # Horus.Blueprint.Operator.Equality,
  # Horus.Blueprint.Operator.Conditional
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
