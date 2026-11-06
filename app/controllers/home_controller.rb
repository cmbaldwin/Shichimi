class HomeController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    return unless authenticated?
    user = current_user
    @stats = Stats.new(user)
    @workout = user.next_routine_workout || Workout.catalog.find_by(slug: "the-original") || Workout.catalog.order(:id).first
    @last_log = user.workout_logs.recent.first
    @greeting = case user.zone.now.hour
    when 5..11 then "Good morning"
    when 12..17 then "Good afternoon"
    else "Good evening"
    end
    @fallen = @stats.current_streak.zero? && user.workout_logs.exists?
    @god = @stats.lucky_gods.find { !it[:unlocked] } if @stats.respond_to?(:lucky_gods)
    @picks = quick_picks(user)
    render :today
  end

  private

  # one quiet, one sprint-format, one from the routine (when it has one); fills with catalog if short
  def quick_picks(user)
    cat = Workout.catalog.order(:id)
    picks = [ cat.find_by(focus: "quiet"), cat.find_by(format: "sprint"), user.routine_workouts.where.not(id: @workout&.id).first ]
    picks.compact.uniq.first(3).then { |p| p.size < 3 ? (p + cat.where.not(id: p.map(&:id) + [ @workout&.id ]).limit(3 - p.size)).first(3) : p }
  end
end
