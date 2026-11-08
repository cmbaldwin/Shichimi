require "test_helper"

class PlayerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
    slugs = Exercise.all.group_by(&:category).values.map(&:first).first(4).map(&:slug)
    attrs = { format: "easy", level: 1, focus: "full", exercise_slugs: slugs }
    @catalog = Workout.create!(attrs.merge(name: "Cat", slug: "cat-test"))
    @mine = Workout.create!(attrs.merge(name: "Mine", user: @user))
    @theirs = Workout.create!(attrs.merge(name: "Theirs", user: @other))
    sign_in_as @user
  end

  test "show and play for catalog and own workouts" do
    [ @catalog, @mine ].each do |w|
      get workout_path(w)
      assert_response :success
      assert_select "details.wo-ex-more a[href^='/exercises/']", w.exercise_slugs.size
      assert_select "details.wo-ex-more a[href^='https://www.youtube.com/']", w.exercise_slugs.size
      get play_workout_path(w)
      assert_response :success
      assert_select "[data-controller~=player]"
    end
  end

  test "someone else's workout is 404" do
    get workout_path(@theirs)
    assert_response :not_found
    get play_workout_path(@theirs)
    assert_response :not_found
  end

  test "play requires login" do
    sign_out
    get play_workout_path(@catalog)
    assert_redirected_to new_session_path
  end

  test "create snapshots the workout and scopes to the user" do
    slugs = @mine.exercise_slugs
    assert_difference -> { @user.workout_logs.count }, 1 do
      post workout_logs_path, params: { workout_id: @mine.id, completed_slugs: slugs + [ "bogus" ], duration_seconds: 300,
                                        started_at: 10.minutes.ago.iso8601, user_id: @other.id }
    end
    log = @user.workout_logs.last
    assert_redirected_to workout_log_path(log)
    assert_equal [ "Mine", "easy", 30, 30 ], [ log.workout_name, log.format, log.work_seconds, log.rest_seconds ]
    assert_equal slugs, log.completed_slugs
    assert_in_delta 10.minutes.ago, log.performed_at, 5
    assert_equal 0, @other.workout_logs.count
  end

  test "partial log, absurd started_at falls back to now, foreign workout 404" do
    post workout_logs_path, params: { workout_id: @catalog.id, completed_slugs: [ @catalog.exercise_slugs.first ], duration_seconds: 40, started_at: "2001-01-01T00:00:00Z" }
    log = @user.workout_logs.last
    assert_equal 1, log.completed_slugs.size
    assert_in_delta Time.current, log.performed_at, 5
    assert_no_difference "WorkoutLog.count" do
      post workout_logs_path, params: { workout_id: @theirs.id }
    end
    assert_response :not_found
  end

  test "summary, rpe and notes update" do
    log = @user.workout_logs.create!(workout: @mine, workout_name: "Mine", format: "easy", work_seconds: 30, rest_seconds: 30,
                                     completed_slugs: @mine.exercise_slugs, duration_seconds: 400, performed_at: Time.current)
    get workout_log_path(log)
    assert_response :success
    assert_select "form[action='#{workout_log_path(log)}'] button", minimum: 10
    patch workout_log_path(log), params: { workout_log: { rpe: 7 } }
    assert_equal 7, log.reload.rpe
    patch workout_log_path(log), params: { workout_log: { notes: "ok" } }
    assert_equal "ok", log.reload.notes
    mine_other = @other.workout_logs.create!(workout_name: "x", format: "easy", work_seconds: 30, rest_seconds: 30, duration_seconds: 1, performed_at: Time.current)
    get workout_log_path(mine_other)
    assert_response :not_found
  end

  test "heart rate is stored when sane, dropped when not, and shown" do
    post workout_logs_path, params: { workout_id: @mine.id, duration_seconds: 60, avg_hr: "142", max_hr: "171" }
    log = @user.workout_logs.last
    assert_equal [ 142, 171 ], [ log.avg_hr, log.max_hr ]
    get workout_log_path(log)
    assert_select "p", /avg 142.*max 171/
    post workout_logs_path, params: { workout_id: @mine.id, duration_seconds: 60, avg_hr: "", max_hr: "999" }
    assert_nil @user.workout_logs.last.avg_hr
    assert_nil @user.workout_logs.last.max_hr
    assert_not @user.workout_logs.build(workout_name: "x", format: "easy", performed_at: Time.current, avg_hr: 5).valid?
  end
end
