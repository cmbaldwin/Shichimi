# Development-only helpers for headless browser checks. Route only exists in development.
class DevController < ApplicationController
  allow_unauthenticated_access
  before_action { head :not_found unless Rails.env.development? }

  # GET /dev/login?to=/stats  → signs in as the seeded demo user, then redirects
  def login
    start_new_session_for User.find_by!(email_address: "demo@shichimi.test")
    redirect_to params[:to].to_s.start_with?("/") ? params[:to] : root_path
  end

  # GET /dev/motion/squat → contact sheet: 12 in-between frames from the front view and a side view.
  def motion
    Exercise.reload!
    @exercise = Exercise.find(params[:slug])
    render layout: false
  end

  # GET /dev/export/squat → samples one loop into a skinned GLB clip (+ camera JSON) and POSTs it back.
  def export
    motion
  end

  # POST /dev/export/squat (raw body) → tmp/exports/<slug>.glb or .json (?kind=json). Feeds script/vork.
  skip_forgery_protection only: :save_export
  def save_export
    # path/query params only: touching `params` makes Rack try to parse the binary body as a form.
    slug = Exercise.find(request.path_parameters[:slug]).slug
    kind = request.query_parameters["kind"] == "json" ? "json" : "glb"
    dir = Rails.root.join("tmp/exports").tap(&:mkpath)
    File.binwrite(dir.join("#{slug}.#{kind}"), request.raw_post)
    head :no_content
  end
end
