class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :workouts, dependent: :destroy # custom workouts
  has_many :routine_items, -> { order(:position) }, dependent: :destroy
  has_many :routine_workouts, through: :routine_items, source: :workout
  has_many :workout_logs, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate { errors.add(:time_zone, "is not a known time zone") unless ActiveSupport::TimeZone[time_zone.to_s] }
  validates :weekly_goal, numericality: { in: 1..14 }
  validates :reminder_time, format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/ }

  def zone = ActiveSupport::TimeZone[time_zone]
  def today = zone.today
  def display_name = name.presence || email_address.split("@").first
  def worked_out_on?(date) = workout_logs.where(performed_at: date.in_time_zone(zone).all_day).exists?

  SMART_LEAD_MINUTES = 15

  # Median local start time (minutes after midnight) of the last 20 workouts in 60 days; nil under 3.
  def usual_workout_minute
    times = workout_logs.where(performed_at: 60.days.ago..).order(performed_at: :desc).limit(20).pluck(:performed_at)
    return if times.size < 3
    times.map { t = it.in_time_zone(zone); t.hour * 60 + t.min }.sort[times.size / 2]
  end

  # "HH:MM" a little before the usual workout time, or nil without enough history.
  def smart_reminder_time
    m = usual_workout_minute or return
    m = [ m - SMART_LEAD_MINUTES, 0 ].max
    format("%02d:%02d", m / 60, m % 60)
  end

  # The fixed daily reminder wins when the user turned it on; otherwise the learned time.
  def effective_reminder_time
    return reminder_time if reminders_enabled?
    smart_reminder_time if smart_reminders?
  end

  # Next workout in the routine rotation: the one after the most recently logged routine workout.
  def next_routine_workout
    items = routine_items.includes(:workout).to_a
    return if items.empty?
    last = workout_logs.where(workout_id: items.map(&:workout_id)).order(:performed_at).last
    idx = last ? items.index { it.workout_id == last.workout_id } : -1
    items[(idx + 1) % items.size].workout
  end
end
