# Local dev/test only: load gitignored .env (VAPID keys etc.). Prod gets ENV from Kamal secrets.
# `dotenv` is already installed as a kamal dependency, so no extra gem.
if Rails.env.local?
  require "dotenv"
  Dotenv.load
end
