class WorkoutLogsController < ApplicationController
  before_action :set_log, only: %i[show update]

  PER_PAGE = 20

  def index
    @page = [ params[:page].to_i, 1 ].max
    scope = current_user.workout_logs.recent
    @total = scope.count
    @logs = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @by_month = @logs.group_by { it.performed_at.in_time_zone(current_user.zone).beginning_of_month }
    @more = @total > @page * PER_PAGE
  end

  def destroy
    current_user.workout_logs.find(params[:id]).destroy
    redirect_to workout_logs_path, notice: "Entry deleted.", status: :see_other
  end

  def show
  end

  def create
    workout = Workout.where(user_id: [ nil, current_user.id ]).find(params.expect(:workout_id))
    f = workout.workout_format
    # keep order and repeats (multi-round) but drop anything unknown
    slugs = Array(params[:completed_slugs]).map(&:to_s).select { Exercise.find_by(it) }
    log = current_user.workout_logs.build(
      workout: workout, workout_name: workout.name, format: workout.format,
      work_seconds: f.work, rest_seconds: f.rest, completed_slugs: slugs,
      duration_seconds: params[:duration_seconds].to_i.clamp(0, 4.hours.to_i),
      performed_at: performed_at
    )
    if log.save
      redirect_to log
    else
      redirect_to workout_path(workout), alert: log.errors.full_messages.to_sentence
    end
  end

  def update
    if @log.update(params.expect(workout_log: %i[rpe notes]))
      redirect_to @log, notice: "Saved."
    else
      redirect_to @log, alert: @log.errors.full_messages.to_sentence
    end
  end

  private

  def set_log = @log = current_user.workout_logs.find(params[:id])

  # started_at from the player, clamped to the last 6 hours; else now.
  def performed_at
    t = Time.zone.parse(params[:started_at].to_s) rescue nil
    t && t > 6.hours.ago && t <= Time.current ? t : Time.current
  end
end
