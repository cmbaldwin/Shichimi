class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :current_user
  around_action :use_user_time_zone

  private

  def current_user = Current.session&.user

  def use_user_time_zone(&)
    Time.use_zone(current_user&.time_zone || "Asia/Tokyo", &)
  end
end
