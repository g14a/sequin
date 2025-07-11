import Config

config :mix_test_interactive,
  clear: true

config :phoenix, :plug_init_mode, :runtime
config :phoenix, :stacktrace_depth, 20

config :phoenix_live_view,
  # Configure your database
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

config :sequin, Sequin.ConsoleLogger, drop_metadata_keys: [:file, :domain, :application]

config :sequin, Sequin.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sequin_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  # High for dev, for benchmarking
  pool_size: 30

config :sequin, Sequin.Vault,
  ciphers: [
    # In AES.GCM, it is important to specify 12-byte IV length for
    # interoperability with other encryption software. See this GitHub issue
    # for more details: https://github.com/danielberkompas/cloak/issues/93
    #
    # In Cloak 2.0, this will be the default iv length for AES.GCM.
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1", key: Base.decode64!("2Sig69bIpuSm2kv0VQfDekET2qy8qUZGI8v3/h3ASiY="), iv_length: 12}
  ]

config :sequin, SequinWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: System.get_env("SERVER_PORT", "4000")],
  # For development, we disable any cache and enable
  # debugging and code reloading.
  #
  # The watchers configuration can be used to run external
  # watchers to your application. For example, we can use it
  # to bundle .js and .css sources.
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "F9DmzIZCZ4Kl17OcwJgcvsRRH34s2lkEvq8HTA0IORAMsEMuWd+pSNUFsX4V9no/",
  watchers: [
    node: ["build.js", "--watch", cd: Path.expand("../assets", __DIR__)],
    # Binding to loopback ipv4 address prevents access from other machines.
    # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
    tailwind: {Tailwind, :install_and_run, [:sequin, ~w(--watch)]}
  ]

config :sequin, SequinWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/sequin_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :sequin, SequinWeb.MetricsEndpoint, http: [ip: {127, 0, 0, 1}, port: System.get_env("SEQUIN_METRICS_PORT", "4001")]

config :sequin, SequinWeb.Router,
  admin_user: "admin",
  admin_password: "admin"

config :sequin,
  api_base_url: "http://localhost:4000",
  features: [
    account_self_signup: :enabled,
    provision_default_user: :disabled,
    function_transforms: :enabled
  ],
  backfill_max_pending_messages: 100_000,
  release_version: System.get_env("RELEASE_VERSION"),
  # Arbitrarily high memory limit in dev
  max_memory_bytes: ("MAX_MEMORY_MB" |> System.get_env("5000") |> String.to_integer()) * 1024 * 1024

# esbuild: {Esbuild, :install_and_run, [:sequin, ~w(--sourcemap=inline --watch)]},

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.

# Enable dev routes for dashboard and mailbox
config :sequin, dev_routes: true, self_hosted: false

# Do not include metadata nor timestamps in development logs

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.

# Initialize plugs at runtime for faster development compilation
# Include HEEx debug annotations as HTML comments in rendered markup
# Enable helpful, but potentially expensive runtime checks

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

if "dev.secret.exs" |> Path.expand(__DIR__) |> File.exists?() do
  import_config "dev.secret.exs"
end

if "dev.local.exs" |> Path.expand(__DIR__) |> File.exists?() do
  import_config "dev.local.exs"
end
