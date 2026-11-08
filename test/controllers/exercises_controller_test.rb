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

  test "show uses the pre-rendered video when public/videos has one, else only the 3D canvas" do
    get exercise_path("squat")
    assert_select "video.ex-video[src='/videos/squat.mp4'][poster='/videos/squat.webp'][autoplay][muted][loop][playsinline]"
    assert_select "canvas.ex-figure[data-controller=figure]"
    assert_select ".ex-3d-toggle input[type=checkbox]"
    get exercise_path("jumping_jacks")
    assert_select "video", 0
    assert_select ".ex-3d-toggle", 0
  end
end
