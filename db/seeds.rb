# Idempotent: safe to run on every deploy (docker-entrypoint runs it after db:prepare).
Workout.sync_catalog!

if Rails.env.development?
  User.find_or_create_by!(email_address: "demo@shichimi.test") do |u|
    u.name = "Demo"
    u.password = "shichimi-demo"
  end.update!(admin: true)
end
