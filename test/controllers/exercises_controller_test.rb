require "test_helper"

class ExercisesControllerTest < ActionDispatch::IntegrationTest
  test "index, category filter, show and pose sheet render without login" do
    get exercises_path
    assert_response :success
    get exercises_path(category: "core")
    assert_response :success
    get exercise_path("push_up")
    assert_response :success
    get exercises_path(sheet: 1)
    assert_response :success
    assert_select "figure.sheet-cell", minimum: 30
  end
end
