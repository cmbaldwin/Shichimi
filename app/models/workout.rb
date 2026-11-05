class Workout < ApplicationRecord
  PREP_SECONDS = 10
  FOCI = %w[full cardio lower upper core quiet standing].freeze

  belongs_to :user, optional: true # nil = catalog
  has_many :routine_items, dependent: :destroy
  has_many :workout_logs, dependent: :nullify

  scope :catalog, -> { where(user_id: nil) }

  validates :name, presence: true
  validates :format, inclusion: { in: -> { WorkoutFormat.keys } }
  validates :level, inclusion: { in: 1..3 }
  validates :focus, inclusion: { in: FOCI }
  validate { errors.add(:exercise_slugs, "must list 2 to 16 exercises") unless (2..16).cover?(exercise_slugs.size) }
  validate { errors.add(:exercise_slugs, "has unknown exercises") unless (exercise_slugs - Exercise.slugs).empty? }

  before_validation { self.exercise_slugs = Array(exercise_slugs).compact_blank }
  before_save :derive_flags

  def catalog? = user_id.nil?
  def workout_format = WorkoutFormat.find(format)
  def exercises = exercise_slugs.map { Exercise.find(it) }

  # Adjacent exercises sharing a category (incl. round wrap-around when rounds run back to back).
  def same_category_neighbours
    cats = exercises.map(&:category)
    pairs = cats.each_cons(2).each_with_index.select { |(a, b), _| a == b }.map { |_, i| [ i, i + 1 ] }
    f = workout_format
    pairs << [ cats.size - 1, 0 ] if f.rounds > 1 && f.round_rest <= f.rest && cats.first == cats.last
    pairs
  end

  # Every step the player runs, in order. Contract shared with player_controller.js.
  #   { kind: "prep"|"work"|"rest", seconds:, slug:, round:, index:, switch_at: (sides exercises only) }
  # rest/prep steps carry the slug of the *upcoming* exercise.
  def timeline
    f = workout_format
    steps = [ { kind: "prep", seconds: PREP_SECONDS, slug: exercise_slugs.first, round: 1, index: 0 } ]
    f.rounds.times do |r|
      exercises.each_with_index do |ex, i|
        work = { kind: "work", seconds: f.work, slug: ex.slug, round: r + 1, index: i }
        work[:switch_at] = f.work / 2 if ex.sides
        steps << work
        nxt = exercise_slugs[i + 1] || (r + 1 < f.rounds ? exercise_slugs.first : nil)
        next unless nxt
        steps << { kind: "rest", seconds: i + 1 < exercises.size ? f.rest : f.round_rest, slug: nxt, round: r + 1, index: i + 1 }
      end
    end
    steps
  end

  def self.sync_catalog!
    YAML.load_file(Rails.root.join("config/catalog/workouts.yml")).each do |h|
      w = catalog.find_or_initialize_by(slug: h.fetch("slug"))
      w.update!(h.slice("name", "format", "level", "focus", "about").merge("exercise_slugs" => h.fetch("exercises")))
    end
  end

  private

  def derive_flags
    exs = exercises
    self.low_impact = exs.all?(&:low_impact?)
    self.needs_floor = exs.any?(&:floor)
    self.equipment = exs.map(&:equipment).compact_blank.uniq.sort.join(" ")
    self.total_seconds = workout_format.total_seconds(exs.size)
  end
end
