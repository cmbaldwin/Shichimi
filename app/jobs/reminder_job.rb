# Runs every 5 minutes (config/recurring.yml). Pushes one "time for your seven" per user per day.
class ReminderJob < ApplicationJob
  def perform(now = Time.current)
    return unless PushService.configured?
    User.where(reminders_enabled: true).includes(:push_subscriptions).find_each { remind(it, now) }
  end

  private

  def remind(user, now)
    local = now.in_time_zone(user.zone)
    return unless user.reminder_days.include?(local.wday.to_s)
    return if local.strftime("%H:%M") < user.reminder_time # zero-padded, so string compare works
    return if user.last_reminded_on == local.to_date || user.worked_out_on?(local.to_date)

    workout = user.next_routine_workout || Workout.find_by(slug: "the-original")
    user.push_subscriptions.each do |sub|
      PushService.deliver(sub, title: "Time for your seven", body: workout ? "Today: #{workout.name}" : "Seven minutes, that's all.", url: "/")
    end
    user.update_column(:last_reminded_on, local.to_date) # even with no subscriptions: don't retry all day
  end
end
