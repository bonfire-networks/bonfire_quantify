use Mix.Config

config :bonfire_quantify,
  web_module: Bonfire.Web,
  repo_module: Bonfire.Repo,
  user_module: CommonsPub.Users.User,
  templates_path: "lib",
  otp_app: :bonfire
