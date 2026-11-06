require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get stats_path
    assert_redirected_to new_session_path
  end

  test "empty state" do
    sign_in_as users(:one)
    get stats_path
    assert_response :success
    assert_select ".empty"
  end

  test "with logs" do
    u = users(:one)
    u.workout_logs.create!(workout_name: "T", format: "classic", work_seconds: 30, rest_seconds: 10,
                           completed_slugs: %w[jumping_jacks squat], duration_seconds: 420, performed_at: Time.current, rpe: 6)
    sign_in_as u
    get stats_path
    assert_response :success
    assert_select ".heatmap i", 182
    assert_select ".god", 7
  end
end
