class SettingsController < ApplicationController
  def show
  end

  def update
    attrs = params.expect(user: %i[name time_zone weight_kg weekly_goal voice figure smart_reminders reminders_enabled reminder_time])
    attrs[:reminder_days] = Array(params.dig(:user, :reminder_days)).grep(/\A[0-6]\z/).uniq.sort.join
    attrs[:weight_kg] = nil if attrs[:weight_kg].blank?
    if current_user.update(attrs)
      redirect_to settings_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
