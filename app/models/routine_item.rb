class RoutineItem < ApplicationRecord
  belongs_to :user
  belongs_to :workout
  validates :workout_id, uniqueness: { scope: :user_id }
  before_create { self.position = user.routine_items.maximum(:position).to_i + 1 }
end
