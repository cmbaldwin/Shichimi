class HomeController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    return unless authenticated?
    user = current_user
    @stats = Stats.new(user)
    @from_routine = user.routine_items.exists?
    @workout = user.next_workout
    @done_today = user.worked_out_on?(user.today)
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

  # Three alternatives by mood, each rotating like the main pick (least recently done first).
  def quick_picks(user)
    cat = Workout.catalog
    { "Quiet" => cat.where(focus: "quiet"), "Short" => cat.where(format: "sprint"), "Gentle" => cat.where(level: 1) }
      .each_with_object({}) { |(label, scope), picks| (w = user.suggested_workout(scope, except: [ @workout&.id, *picks.values.map(&:id) ])) && picks[label] = w }
  end
end
