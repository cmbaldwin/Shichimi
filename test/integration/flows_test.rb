require "test_helper"

class FlowsTest < ActionDispatch::IntegrationTest
  setup do
    Workout.sync_catalog!
    # independent of the catalog agent's progress: ensure a few catalog rows exist
    3.times { |i| Workout.catalog.find_or_create_by!(slug: "t#{i}") { it.assign_attributes(name: "T#{i}", format: "sprint", focus: "full", level: 2, exercise_slugs: Exercise.all.first(8).map(&:slug)) } }
    @user = users(:one)
    @other = users(:two)
    @catalog = Workout.catalog.order(:id).first
  end

  def custom(user, name = "Mine")
    user.workouts.create!(name:, format: "sprint", focus: "full", level: 2, exercise_slugs: Exercise.all.first(8).map(&:slug))
  end

  test "landing vs today" do
    get root_url
    assert_select "h1", /Seven minutes/
    sign_in_as @user
    get root_url
    assert_response :success
    assert_select "a[href=?]", play_workout_path(Workout.catalog.find_by(slug: "the-original") || @catalog)
  end

  test "library filters" do
    sign_in_as @user
    get workouts_url
    assert_response :success
    get workouts_url(fmt: "sprint", low_impact: 1)
    assert_response :success
    assert Workout.catalog.where(format: "sprint", low_impact: true).all? { it.format == "sprint" }
    get workouts_url(q: "zzzzzz")
    assert_select ".card", text: /Nothing matches/
  end

  test "custom workout crud and ownership" do
    sign_in_as @user
    slugs = Exercise.all.first(8).map(&:slug)
    assert_difference -> { @user.workouts.count } do
      post workouts_url, params: { workout: { name: "Mine", format: "sprint", focus: "full", level: 2, exercise_slugs: slugs + [ "" ] } }
    end
    w = @user.workouts.last
    assert_redirected_to workout_url(w)
    patch workout_url(w), params: { workout: { name: "Renamed" } }
    assert_equal "Renamed", w.reload.name
    theirs = custom(@other, "Theirs")
    get edit_workout_url(theirs)
    assert_response :not_found
    delete workout_url(theirs)
    assert_response :not_found
    delete workout_url(w)
    assert_not Workout.exists?(w.id)
  end

  test "routine add move remove and rotation" do
    sign_in_as @user
    a, b = Workout.catalog.order(:id).first(2)
    post routine_items_url, params: { workout_id: a.id }
    post routine_items_url, params: { workout_id: b.id }
    assert_equal [ a, b ], @user.routine_workouts.reload.to_a
    assert_equal a, @user.next_routine_workout
    patch move_routine_item_url(@user.routine_items.last), params: { direction: "up" }
    assert_equal [ b, a ], @user.routine_workouts.reload.to_a
    @user.workout_logs.create!(workout: b, workout_name: b.name, format: b.format, work_seconds: 20, rest_seconds: 10, performed_at: Time.current)
    assert_equal a, @user.next_routine_workout
    delete routine_item_url(@user.routine_items.first)
    assert_equal 1, @user.routine_items.count
    get routine_items_url
    assert_response :success
  end

  test "history index and destroy are scoped" do
    mk = ->(u, n) { u.workout_logs.create!(workout_name: n, format: "sprint", work_seconds: 20, rest_seconds: 10, performed_at: Time.current) }
    mine = mk.(@user, "MyLog")
    theirs = mk.(@other, "TheirLog")
    sign_in_as @user
    get workout_logs_url
    assert_match "MyLog", response.body
    assert_no_match "TheirLog", response.body
    delete workout_log_url(theirs)
    assert_response :not_found
    delete workout_log_url(mine)
    assert_not WorkoutLog.exists?(mine.id)
  end

  test "settings update" do
    sign_in_as @user
    get settings_url
    assert_response :success
    patch settings_url, params: { user: { name: "Zed", time_zone: "America/Denver", weight_kg: "70.5", weekly_goal: 3, voice: "male", reminders_enabled: "1", reminder_time: "06:30", reminder_days: %w[1 3 5] } }
    @user.reload
    assert_equal [ "Zed", "America/Denver", 3, "135", "06:30" ], [ @user.name, @user.time_zone, @user.weekly_goal, @user.reminder_days, @user.reminder_time ]
    assert_equal "male", @user.voice
    patch settings_url, params: { user: { time_zone: "Nowhere/Land" } }
    assert_response :unprocessable_entity
  end
end
