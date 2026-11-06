require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "science is public" do
    get science_path
    assert_response :success
    assert_select "h1", "Why it works"
    assert_select "article.science-format", WorkoutFormat.all.size
  end

  test "install guide is public" do
    get install_path
    assert_response :success
    assert_select "h2", /iPhone/
    assert_select "h2", /Android/
  end
end
