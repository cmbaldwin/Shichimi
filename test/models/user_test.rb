require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "voice defaults to female and only accepts female, male or off" do
    user = User.new(email_address: "v@example.com", password: "password123")
    assert_equal "female", user.voice
    user.voice = "robot"
    assert_not user.valid?
    assert user.errors.of_kind?(:voice, :inclusion)
  end
end
