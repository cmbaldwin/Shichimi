# frozen_string_literal: true

# In-process error tracker: dashboard at /uchujin, own tables in the primary DB.
# Mirrors akotacos.moab.jp. Engine controllers do not include Authentication,
# so the Rails 8 session cookie is resolved here.
Uchujin.configure do |config|
  config.app_name = "Shichimi"

  config.authenticate do
    user = Session.find_by(id: cookies.signed[:session_id])&.user
    redirect_to "/session/new", alert: "Unauthorized" unless user&.admin?
  end
  config.current_user_method { Session.find_by(id: cookies.signed[:session_id])&.user }

  # Capture in production only (off in dev and test).
  config.environments = %w[production]

  config.ignored_exceptions << "ActionController::InvalidAuthenticityToken"
  config.ignored_exceptions << "ActionController::UnknownFormat"
  config.ignored_exceptions << "Rack::BadRequest"
  config.ignored_exceptions << "SystemExit"

  config.notification_email = "cody@moab.jp"
  config.mailer_from = "Shichimi <noreply@shichimi.moab.jp>"
  config.deploy_token = ENV["UCHUJIN_DEPLOY_TOKEN"]
  config.revision = ENV["GIT_REVISION"].presence || ENV["KAMAL_VERSION"]

  # MCP triage API at POST /uchujin/api/mcp
  config.mcp_enabled = ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("UCHUJIN_MCP_ENABLED", Rails.env.production? ? "true" : "false")
  )
  config.mcp_token = ENV["UCHUJIN_MCP_TOKEN"]

  config.queue_name = :default
  config.pruning_enabled = true
  config.retention_period = 90.days
  config.resolved_retention_period = 30.days
end
