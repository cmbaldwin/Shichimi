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
    with, without = Exercise.all.partition(&:video).map { it.map(&:slug) }
    if (slug = with.first)
      get exercise_path(slug)
      v = Exercise.find(slug).video
      assert_select "video.ex-video[src='#{v[:mp4]}'][poster='#{v[:webp]}'][autoplay][muted][loop][playsinline]"
      assert_select "canvas.ex-figure[data-controller=figure]"
      assert_select ".ex-3d-toggle input[type=checkbox]"
    end
    if (slug = without.first)
      get exercise_path(slug)
      assert_select "video", 0
      assert_select ".ex-3d-toggle", 0
    end
  end
end
