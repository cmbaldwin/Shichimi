class WorkoutLog < ApplicationRecord
  belongs_to :user
  belongs_to :workout, optional: true

  validates :workout_name, :format, :performed_at, presence: true
  validates :rpe, inclusion: { in: 1..10 }, allow_nil: true
  validates :avg_hr, :max_hr, inclusion: { in: 30..240 }, allow_nil: true
  validate { errors.add(:completed_slugs, "has unknown exercises") unless (Array(completed_slugs) - Exercise.slugs).empty? }

  scope :recent, -> { order(performed_at: :desc) }

  def work_total = completed_slugs.size * work_seconds
  def exercises = completed_slugs.filter_map { Exercise.find_by(it) }
  # Estimated kcal: MET × kg × hours of work time (Compendium of Physical Activities). nil without a weight.
  def kcal(weight_kg = user.weight_kg)
    return unless weight_kg
    (exercises.sum { it.met.to_f * work_seconds } * weight_kg.to_f / 3600).round
  end

  def heart_rate(kind) = (self[kind] if has_attribute?(kind)) # avg_hr / max_hr, when that migration exists
end
