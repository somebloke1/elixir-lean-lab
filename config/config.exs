import Config

config :elixir_lean_lab,
  env: config_env()

config :logger,
  level: :info,
  backends: [:console]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"