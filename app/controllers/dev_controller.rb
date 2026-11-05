# Development-only helpers for headless browser checks. Route only exists in development.
class DevController < ApplicationController
  allow_unauthenticated_access
  before_action { head :not_found unless Rails.env.development? }

  # GET /dev/login?to=/stats  → signs in as the seeded demo user, then redirects
  def login
    start_new_session_for User.find_by!(email_address: "demo@shichimi.test")
    redirect_to params[:to].to_s.start_with?("/") ? params[:to] : root_path
  end
end
