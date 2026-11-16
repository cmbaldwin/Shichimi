# Idempotent: safe to run on every deploy (docker-entrypoint runs it after db:prepare).
Workout.sync_catalog!

# Demo user only when explicitly opted in (keeps a password out of the public repo).
if Rails.env.development? && ENV["SHICHIMI_DEMO_PASSWORD"].present?
  User.find_or_create_by!(email_address: "demo@shichimi.test") do |u|
    u.name = "Demo"
    u.password = ENV.fetch("SHICHIMI_DEMO_PASSWORD")
  end.update!(admin: true)
end
