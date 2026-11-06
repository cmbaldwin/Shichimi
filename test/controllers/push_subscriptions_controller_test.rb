require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one); @other = users(:two) }

  def sub_params(endpoint = "https://push.example/abc")
    { subscription: { endpoint:, keys: { p256dh: "p", auth: "a" } } }
  end

  test "create requires login" do
    post push_subscriptions_path, params: sub_params, as: :json
    assert_redirected_to new_session_path
  end

  test "create upserts by endpoint for the current user" do
    sign_in_as @user
    assert_difference -> { @user.push_subscriptions.count }, 1 do
      post push_subscriptions_path, params: sub_params, as: :json
      post push_subscriptions_path, params: sub_params, as: :json
    end
    assert_response :created
  end

  test "create cannot take over another user's endpoint" do
    @other.push_subscriptions.create!(endpoint: "https://push.example/abc", p256dh_key: "x", auth_key: "y")
    sign_in_as @user
    post push_subscriptions_path, params: sub_params, as: :json
    assert_response :forbidden
    assert_equal @other, PushSubscription.find_by!(endpoint: "https://push.example/abc").user
  end

  test "destroy only removes the current user's subscription" do
    mine = @user.push_subscriptions.create!(endpoint: "https://push.example/mine", p256dh_key: "x", auth_key: "y")
    theirs = @other.push_subscriptions.create!(endpoint: "https://push.example/theirs", p256dh_key: "x", auth_key: "y")
    sign_in_as @user
    delete push_subscriptions_path, params: { endpoint: theirs.endpoint }, as: :json
    assert PushSubscription.exists?(theirs.id)
    delete push_subscriptions_path, params: { endpoint: mine.endpoint }, as: :json
    assert_response :no_content
    assert_not PushSubscription.exists?(mine.id)
  end
end
