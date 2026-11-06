require "test_helper"

class WorkoutTest < ActiveSupport::TestCase
  def build(format, slugs, **attrs)
    Workout.new({ name: "T", format: format, level: 1, focus: "full", exercise_slugs: slugs }.merge(attrs))
  end

  CLASSIC = %w[jumping_jacks squat push_up crunch].freeze

  test "timeline starts with prep carrying the first slug" do
    tl = build("classic", CLASSIC).timeline
    assert_equal({ kind: "prep", seconds: Workout::PREP_SECONDS, slug: "jumping_jacks", round: 1, index: 0 }, tl.first)
  end

  test "rest carries the upcoming slug and there is no trailing rest" do
    tl = build("classic", CLASSIC).timeline
    tl.each_cons(2) { |a, b| assert_equal b[:slug], a[:slug], "rest" if a[:kind] == "rest" && b[:kind] == "work" }
    tl.each_with_index { |s, i| assert_equal tl[i + 1][:slug], s[:slug] if s[:kind] == "rest" }
    assert_equal "work", tl.last[:kind]
    assert_equal 4, tl.count { it[:kind] == "work" }
    assert_equal 3, tl.count { it[:kind] == "rest" }
    assert_equal %w[prep work rest work rest work rest work], tl.map { it[:kind] }
  end

  test "tabata wraps from the last exercise of round one into the first of round two" do
    slugs = %w[jumping_jacks squat push_up crunch high_knees lunge tricep_dip]
    tl = build("tabata", slugs).timeline
    assert_equal 14, tl.count { it[:kind] == "work" }
    wrap = tl[tl.index { it[:kind] == "work" && it[:round] == 1 && it[:index] == 6 } + 1]
    assert_equal "rest", wrap[:kind]
    assert_equal "jumping_jacks", wrap[:slug]
    assert_equal 2, tl.select { it[:kind] == "work" && it[:slug] == "jumping_jacks" }.last[:round]
    assert_equal "work", tl.last[:kind]
  end

  test "side plank carries switch_at at half the work time and others do not" do
    tl = build("classic", %w[push_up side_plank squat side_plank]).timeline
    works = tl.select { it[:kind] == "work" }
    assert_equal [ nil, 15, nil, 15 ], works.map { it[:switch_at] }
    refute tl.any? { it[:kind] != "work" && it.key?(:switch_at) }
    assert_equal 25, build("fifty_ten", %w[side_plank squat]).timeline[1][:switch_at]
  end

  test "work plus rest seconds equal the format total for every format" do
    WorkoutFormat.all.each do |f|
      slugs = Exercise.slugs.first(f.stations)
      tl = build(f.key, slugs).timeline
      assert_equal f.total_seconds(f.stations), tl.reject { it[:kind] == "prep" }.sum { it[:seconds] }, f.key
    end
  end

  test "round rest is used at the round boundary only" do
    f = WorkoutFormat.find("double")
    tl = build("double", Exercise.slugs.first(12)).timeline
    rests = tl.select { it[:kind] == "rest" }.map { it[:seconds] }
    assert_equal f.round_rest, rests[11]
    assert_equal 1, rests.count(f.round_rest)
    assert_equal 23, rests.size
  end

  test "derived flags: low_impact, needs_floor, equipment and total_seconds" do
    w = build("classic", %w[squat tricep_dip wall_sit plank])
    w.save!
    assert w.low_impact
    assert w.needs_floor
    assert_equal "chair wall", w.equipment
    assert_equal WorkoutFormat.find("classic").total_seconds(4), w.total_seconds

    w2 = build("classic", %w[jumping_jacks squat])
    w2.save!
    refute w2.low_impact
    refute w2.needs_floor
    assert_equal "", w2.equipment
  end

  test "same_category_neighbours reports adjacent pairs and the tabata wrap" do
    assert_equal [ [ 0, 1 ] ], build("classic", %w[squat sumo_squat push_up]).same_category_neighbours
    assert_equal [ [ 2, 0 ] ], build("tabata", %w[squat push_up lunge]).same_category_neighbours
    assert_empty build("classic", %w[squat push_up lunge]).same_category_neighbours
  end

  test "validations reject bad format, level, focus and unknown exercises" do
    refute build("nope", CLASSIC).valid?
    refute build("classic", CLASSIC, level: 4).valid?
    refute build("classic", CLASSIC, focus: "legs").valid?
    refute build("classic", %w[squat nonsense]).valid?
    refute build("classic", %w[squat]).valid?
  end
end
