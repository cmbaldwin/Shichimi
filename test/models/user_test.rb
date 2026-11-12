require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "voice defaults to female and only accepts female, male or off" do
    user = User.new(email_address: "v@example.com", password: "password123")
    assert_equal "female", user.voice
    user.voice = "robot"
    assert_not user.valid?
    assert user.errors.of_kind?(:voice, :inclusion)
  end

  test "today's workout moves on: a new spice each time, then least recently done; a routine wins" do
    Workout.sync_catalog!
    user = users(:one)
    done = 12.times.map do |i|
      w = user.next_workout
      user.workout_logs.create!(workout: w, workout_name: w.name, format: w.format, work_seconds: 30, rest_seconds: 10,
                                completed_slugs: [], duration_seconds: 60, performed_at: (12 - i).hours.ago)
      w
    end
    assert_equal "the-original", done.first.slug
    assert_equal 12, done.uniq.size, "never repeats while undone workouts remain"
    assert_equal WorkoutFormat.keys.sort, done.first(7).map(&:format).sort, "first seven cover all seven spices"
    assert done.first(10).all? { it.level < 3 }, "no Hard workouts in the first ten"

    user.routine_items.create!(workout: done.first)
    assert_equal done.first, user.next_workout
  end
end
