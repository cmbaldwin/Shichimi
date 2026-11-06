class WorkoutsController < ApplicationController
  before_action :set_workout, only: %i[show play]
  before_action :set_own_workout, only: %i[edit update destroy]

  def index
    @mine = params[:scope] == "mine"
    scope = @mine ? current_user.workouts : Workout.catalog
    scope = scope.where(format: params[:fmt]) if params[:fmt].present?
    scope = scope.where(focus: params[:focus]) if params[:focus].present?
    scope = scope.where(level: params[:level]) if params[:level].present?
    scope = scope.where(low_impact: true) if params[:low_impact] == "1"
    scope = scope.where(needs_floor: false) if params[:no_floor] == "1"
    scope = scope.where(equipment: "") if params[:no_equipment] == "1"
    scope = scope.where("workouts.name LIKE ?", "%#{Workout.sanitize_sql_like(params[:q].to_s.strip)}%") if params[:q].present?
    @workouts = scope.order(:id)
  end

  def new
    @workout = current_user.workouts.build(format: "classic", level: 2, focus: "full")
  end

  def create
    @workout = current_user.workouts.build(workout_params)
    if @workout.save
      redirect_to workout_path(@workout), notice: neighbour_notice("Workout saved.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workout.update(workout_params)
      redirect_to workout_path(@workout), notice: neighbour_notice("Workout updated.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workout.destroy
    redirect_to workouts_path(scope: "mine"), notice: "Workout deleted.", status: :see_other
  end

  def show
    @exercises = @workout.exercises
    @neighbours = @workout.same_category_neighbours
  end

  def play
    @exercises = @workout.exercises.uniq
  end

  private

  # Catalog workouts or the current user's own; anything else is a 404.
  def find_workout(id = params[:id])
    Workout.where(user_id: [ nil, current_user.id ]).find(id)
  end

  def set_workout = @workout = find_workout

  def set_own_workout = @workout = current_user.workouts.find(params[:id])

  def workout_params
    params.expect(workout: [ :name, :format, :focus, :level, :about, { exercise_slugs: [] } ])
  end

  # Same-category neighbours are advice, not a validation error.
  def neighbour_notice(msg)
    return msg if (pairs = @workout.same_category_neighbours).empty?
    names = pairs.map { |a, b| "#{@workout.exercises[a].name} / #{@workout.exercises[b].name}" }.to_sentence
    "#{msg} Heads up: back-to-back same-category stations (#{names}) work the same muscles with no recovery."
  end
end
