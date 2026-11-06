require "test_helper"

class StatsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(time_zone: "Asia/Tokyo", weekly_goal: 3)
    @today = Date.new(2026, 11, 6) # Friday
  end

  def log!(date, hour: 7, slugs: %w[jumping_jacks squat], min: 7, **extra)
    @user.workout_logs.create!({ workout_name: "T", format: "classic", work_seconds: 30, rest_seconds: 10,
      completed_slugs: slugs, duration_seconds: min * 60,
      performed_at: @user.zone.local(date.year, date.month, date.day, hour) }.merge(extra))
  end

  def stats = Stats.new(@user, today: @today)

  test "empty user" do
    assert_equal 0, stats.current_streak
    assert_not stats.any?
    assert_nil stats.days_since_last_workout
  end

  test "streak counts today and yesterday, breaks on a gap" do
    log!(@today); log!(@today - 1); log!(@today - 3)
    assert_equal 2, stats.current_streak
    assert_equal 2, stats.longest_streak
  end

  test "streak still alive when last log was yesterday" do
    log!(@today - 1); log!(@today - 2)
    assert_equal 2, stats.current_streak
  end

  test "streak dead after two missed days, longest survives" do
    log!(@today - 2); log!(@today - 3); log!(@today - 4)
    assert_equal 0, stats.current_streak
    assert_equal 3, stats.longest_streak
  end

  test "23:30 Tokyo counts for the Tokyo day" do
    log!(@today, hour: 23)
    @user.workout_logs.last.update!(performed_at: @user.zone.local(2026, 11, 6, 23, 30))
    assert_equal 1, stats.current_streak
    assert_equal 0, stats.days_since_last_workout
    assert_equal 1, stats.weekday_histogram[4]
    assert_equal 23, stats.hour_histogram.index(1)
  end

  test "week is Monday to Sunday with minutes" do
    log!(@today - 4, min: 10)
    w = stats.week
    assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 8) ], [ w.first[:date], w.last[:date] ]
    assert_equal({ date: w.first[:date], done: true, minutes: 10 }, w.first)
    assert_equal({ done_days: 1, goal: 3 }, stats.weekly_goal_progress)
  end

  test "WHO counting: vigorous minutes and strengthening days" do
    log!(@today, slugs: %w[jumping_jacks squat]) # cardio+lower: counts (2*30s = 1 min)
    log!(@today - 1, slugs: %w[jumping_jacks]) # cardio only: not a strength day
    who = stats.who_targets
    assert_equal 75, who[:vigorous][:target]
    assert_equal 2, who[:vigorous][:value] # 3 slugs * 30s = 1.5 -> 2
    assert_equal 1, who[:strength_days][:value]
  end

  test "heatmap is 26 whole weeks" do
    assert_equal 182, stats.heatmap.size
    assert_equal 12, stats.weekly_series.size
  end

  test "lucky gods unlock by milestone and keep longest streak" do
    assert_equal 7, stats.lucky_gods.size
    assert stats.lucky_gods.none? { it[:unlocked] }
    (10..14).each { log!(@today - it) } # a 5-day streak long ago
    gods = stats.lucky_gods.index_by { it[:key] }
    assert gods["ebisu"][:unlocked]
    assert_equal @today - 14, gods["ebisu"][:unlocked_on]
    assert gods["daikokuten"][:unlocked]
    assert_equal @today - 12, gods["daikokuten"][:unlocked_on]
    assert_not gods["benzaiten"][:unlocked]
    assert_equal [ 5, 7 ], gods["benzaiten"].values_at(:progress, :goal)
  end

  test "total-based gods unlock at 25 workouts" do
    25.times { |i| log!(@today - i * 2) }
    gods = stats.lucky_gods.index_by { it[:key] }
    assert gods["bishamonten"][:unlocked]
    assert_not gods["fukurokuju"][:unlocked]
    assert_equal 25, gods["fukurokuju"][:progress]
  end
end
