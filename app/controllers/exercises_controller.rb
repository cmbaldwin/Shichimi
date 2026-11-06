class ExercisesController < ApplicationController
  allow_unauthenticated_access

  def index
    @category = params[:category].presence_in(Exercise.categories)
    @exercises = @category ? Exercise.all.select { it.category == @category } : Exercise.all
    render :sheet if params[:sheet].present?
  end

  def show
    @exercise = Exercise.find_by(params[:id]) or raise ActiveRecord::RecordNotFound
    @workouts = Workout.catalog.order(:name).select { it.exercise_slugs.include?(@exercise.slug) }
  end
end
