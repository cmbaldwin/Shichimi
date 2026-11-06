class RoutineItemsController < ApplicationController
  def index
    @items = current_user.routine_items.includes(:workout)
    @next = current_user.next_routine_workout
  end

  def create
    workout = Workout.where(user_id: [ nil, current_user.id ]).find(params.expect(:workout_id))
    item = current_user.routine_items.find_or_initialize_by(workout: workout)
    item.save!
    redirect_back_or_to routine_items_path, notice: "#{workout.name} added to your routine."
  end

  def move
    items = current_user.routine_items.to_a
    i = items.index { it.id == params[:id].to_i } or raise ActiveRecord::RecordNotFound
    j = params[:direction] == "up" ? i - 1 : i + 1
    if j.between?(0, items.size - 1)
      # positions can tie or have gaps, so renumber the whole list
      items[i], items[j] = items[j], items[i]
      RoutineItem.transaction { items.each_with_index { |item, n| item.update_column(:position, n + 1) } }
    end
    redirect_to routine_items_path, status: :see_other
  end

  def destroy
    current_user.routine_items.find(params[:id]).destroy
    redirect_to routine_items_path, status: :see_other
  end
end
