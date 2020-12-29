use Mix.Config

config :bonfire_quantify,
  otp_app: :your_app_name,
  web_module: Bonfire.Web,
  endpoint_module: Bonfire.Web.Endpoint,
  repo_module: Bonfire.Repo,
  user_schema: CommonsPub.Users.User,
  templates_path: "lib"

# specify what types a unit can have as context
config :bonfire_quantify, Bonfire.Quantify.Units, valid_contexts: [Bonfire.Quantify.Units]
