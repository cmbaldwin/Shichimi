require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  COUNTS = { "classic" => 25, "tabata" => 15, "fifty_ten" => 18, "forty_twenty" => 15, "easy" => 12, "double" => 7, "sprint" => 8 }.freeze
  CATALOG = YAML.load_file(Rails.root.join("config/catalog/workouts.yml")).freeze
  ORIGINAL = %w[jumping_jacks wall_sit push_up crunch step_up squat tricep_dip plank high_knees lunge push_up_rotation side_plank].freeze

  def exercises_of(h) = h["exercises"].map { Exercise.find(it) }

  def categories_of(h)
    cats = exercises_of(h).map(&:category)
    f = WorkoutFormat.find(h["format"])
    pairs = cats.each_cons(2).to_a
    pairs << [ cats.last, cats.first ] if f.rounds > 1 && f.round_rest <= f.rest
    pairs
  end

  test "there are exactly 100 catalog workouts with the planned format counts" do
    assert_equal 100, CATALOG.size
    assert_equal COUNTS, CATALOG.group_by { it["format"] }.transform_values(&:size)
  end

  test "every exercise links a YouTube demo and a written form guide" do
    Exercise.all.each do |ex|
      ref = ex.reference || {}
      assert_match %r{\Ahttps://www\.youtube\.com/watch\?v=[\w-]{11}\z}, ref["video_url"].to_s, ex.slug
      assert_match %r{\Ahttps://}, ref["source_url"].to_s, ex.slug
      assert ref["source_name"].present? && ref["video_title"].present?, ex.slug
    end
  end

  test "names and slugs are unique" do
    assert_equal CATALOG.size, CATALOG.map { it["slug"] }.uniq.size
    assert_equal CATALOG.size, CATALOG.map { it["name"].downcase }.uniq.size
  end

  test "every workout has required fields and a sane about text" do
    CATALOG.each do |h|
      assert_includes WorkoutFormat.keys, h["format"], h["slug"]
      assert_includes 1..3, h["level"], h["slug"]
      assert_includes Workout::FOCI, h["focus"], h["slug"]
      assert h["about"].to_s.length.between?(30, 400), "#{h["slug"]} about length"
    end
  end

  test "station count equals the format and all slugs exist" do
    CATALOG.each do |h|
      assert_equal WorkoutFormat.find(h["format"]).stations, h["exercises"].size, h["slug"]
      assert_empty h["exercises"] - Exercise.slugs, h["slug"]
    end
  end

  test "no exercise repeats within a workout except sprint pairs" do
    CATALOG.each do |h|
      slugs = h["exercises"]
      if h["format"] == "sprint" && slugs.uniq.size < slugs.size
        assert_equal 2, slugs.uniq.size, "#{h["slug"]} sprint must be a pair or distinct"
        assert_equal slugs.first(2) * 4, slugs, h["slug"]
      else
        assert_equal slugs.size, slugs.uniq.size, h["slug"]
      end
    end
  end

  test "no adjacent exercises share a category, including the tabata wrap" do
    CATALOG.each do |h|
      categories_of(h).each { |a, b| refute_equal a, b, "#{h["slug"]} has adjacent #{a}" }
    end
    assert_equal 2, WorkoutFormat.find("tabata").rounds
  end

  test "Workout#same_category_neighbours is empty for every catalog workout" do
    Workout.sync_catalog!
    Workout.catalog.each { |w| assert_empty w.same_category_neighbours, w.slug }
  end

  test "quiet workouts are all low impact and standing workouts have no floor work" do
    CATALOG.select { it["focus"] == "quiet" }.each { |h| assert exercises_of(h).all?(&:low_impact?), h["slug"] }
    CATALOG.select { it["focus"] == "standing" }.each { |h| assert exercises_of(h).none?(&:floor), h["slug"] }
    assert CATALOG.count { it["focus"] == "quiet" } >= 5
    assert CATALOG.count { it["focus"] == "standing" } >= 5
  end

  test "every focus is represented" do
    assert_equal Workout::FOCI.sort, CATALOG.map { it["focus"] }.uniq.sort
  end

  test "the original is the exact Klika and Jordan twelve, plus a double version" do
    o = CATALOG.find { it["slug"] == "the-original" }
    assert_equal ORIGINAL, o["exercises"]
    assert_equal [ "classic", 2 ], [ o["format"], o["level"] ]
    assert CATALOG.any? { it["format"] == "double" && it["exercises"] == ORIGINAL }
  end

  test "only the two allowed studies are cited by name in about text" do
    CATALOG.each do |h|
      refute_match(/ACSM|WHO|McRae|Archila/, h["about"], h["slug"])
      h["about"].scan(/[A-Z][a-z]+ (?:&|et al\.)[^,.]*\(?\d{4}\)?/).each do |cite|
        assert_match(/Klika & Jordan|Tabata et al/, cite, "#{h["slug"]} cites #{cite}")
      end
    end
  end

  test "thirty exercises with all content fields filled" do
    assert_equal 30, Exercise.all.size
    assert_equal Exercise.slugs.size, Exercise.slugs.uniq.size
    Exercise.all.each do |e|
      assert e.ja.present?, "#{e.slug} ja"
      assert_includes 3..5, e.muscles.size, "#{e.slug} muscles"
      assert_includes 3..4, e.cues.size, "#{e.slug} cues"
      e.cues.each { |c| assert c.split.size <= 9, "#{e.slug} cue too long: #{c}" }
      assert e.easier.present?, "#{e.slug} easier"
      assert e.harder.present?, "#{e.slug} harder"
      assert e.met.to_f.between?(2.5, 8.5), "#{e.slug} met"
      assert_includes Exercise.categories, e.category
    end
  end

  test "every exercise appears in at least one catalog workout" do
    used = CATALOG.flat_map { it["exercises"] }.uniq
    assert_empty Exercise.slugs - used
  end

  test "easier and harder differ from the exercise itself" do
    Exercise.all.each { |e| refute_equal e.easier, e.harder, e.slug }
  end

  test "sync_catalog! is idempotent" do
    2.times { Workout.sync_catalog! }
    assert_equal 100, Workout.catalog.count
    assert_equal 100, Workout.catalog.distinct.count(:slug)
  end

  test "every catalog workout passes model validations and syncs flags" do
    Workout.sync_catalog!
    Workout.catalog.each do |w|
      assert w.valid?, "#{w.slug}: #{w.errors.full_messages.to_sentence}"
      assert_equal w.workout_format.total_seconds(w.exercise_slugs.size), w.total_seconds
    end
  end
end
