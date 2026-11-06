require "test_helper"
require "minitest/mock"

class ReminderJobTest < ActiveJob::TestCase
  # 2026-11-02 is a Monday. 22:00 UTC = 07:00 Tuesday in Tokyo, 17:00 Monday in New York.
  NOW = Time.utc(2026, 11, 2, 22, 0)

  setup do
    @user = users(:one)
    @user.update!(reminders_enabled: true, reminder_time: "07:00", reminder_days: "0123456", time_zone: "Asia/Tokyo", last_reminded_on: nil)
    @user.push_subscriptions.create!(endpoint: "https://push.example/1", p256dh_key: "p", auth_key: "a")
    @sent = []
  end

  def run_job(now = NOW, result: :sent)
    PushService.stub(:configured?, true) do
      PushService.stub(:deliver, ->(sub, **kw) { @sent << kw; result }) { ReminderJob.perform_now(now) }
    end
  end

  test "sends once local time has passed and records the day" do
    run_job
    assert_equal [ "Time for your seven" ], @sent.map { it[:title] }
    assert_equal Date.new(2026, 11, 3), @user.reload.last_reminded_on
    run_job
    assert_equal 1, @sent.size
  end

  test "waits until the user's local reminder time" do
    run_job(Time.utc(2026, 11, 2, 21, 59)) # 06:59 in Tokyo
    assert_empty @sent
    run_job
    assert_equal 1, @sent.size
  end

  test "uses the user's time zone for the weekday" do
    @user.update!(reminder_days: "1") # Monday only: Tokyo is Tuesday now
    run_job
    assert_empty @sent
    @user.update!(time_zone: "America/New_York", reminder_time: "17:00") # Monday 17:00 there
    run_job
    assert_equal 1, @sent.size
  end

  test "skips when disabled, already reminded, or already worked out today" do
    @user.update!(reminders_enabled: false)
    run_job
    @user.update!(reminders_enabled: true, last_reminded_on: Date.new(2026, 11, 3))
    run_job
    @user.update!(last_reminded_on: nil)
    @user.workout_logs.create!(workout_name: "x", format: "classic", work_seconds: 30, rest_seconds: 10, performed_at: NOW + 1.minute)
    run_job
    assert_empty @sent
  end

  test "deliver drops expired subscriptions" do
    sub = @user.push_subscriptions.first
    WebPush.stub(:payload_send, ->(**) { raise WebPush::ExpiredSubscription.new(Struct.new(:body, :inspect).new("", ""), "h") }) do
      PushService.stub(:vapid_public_key, "k") { assert_equal :gone, PushService.deliver(sub, title: "t", body: "b") }
    end
    assert_not PushSubscription.exists?(sub.id)
  end
end
