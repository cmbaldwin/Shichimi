require "test_helper"

class UchujinGateTest < ActionDispatch::IntegrationTest
  test "anonymous visitors cannot see the dashboard" do
    get "/uchujin"
    assert_redirected_to "/session/new"
  end

  test "non-admin users are turned away" do
    sign_in_as users(:one)
    get "/uchujin"
    assert_redirected_to "/session/new"
  end

  test "admins get in" do
    user = users(:one)
    user.update!(admin: true)
    sign_in_as user
    get "/uchujin"
    assert_response :success
  end
end
