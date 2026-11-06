require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "science is public" do
    get science_path
    assert_response :success
    assert_select "h1", "Why it works"
    assert_select "article.science-format", WorkoutFormat.all.size
  end
end
