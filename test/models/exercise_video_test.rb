require "test_helper"

class ExerciseVideoTest < ActiveSupport::TestCase
  teardown { Exercise.reload! }

  test "prefers the chosen figure, falls back to the single render, else nil" do
    ex = Exercise.all.first
    Exercise.instance_variable_set(:@videos, { "female/#{ex.slug}" => "aa", ex.slug => "bb" })
    assert_equal({ mp4: "/videos/female/#{ex.slug}.mp4?v=aa", webp: "/videos/female/#{ex.slug}.webp?v=aa" }, ex.video("female"))
    assert_equal "/videos/#{ex.slug}.mp4?v=bb", ex.video("male")[:mp4]
    Exercise.instance_variable_set(:@videos, {})
    assert_nil ex.video("female")
    assert_nil ex.to_player("female")[:video]
  end

  test "users pick a known figure" do
    assert_not users(:one).tap { it.figure = "robot" }.valid?
    assert users(:one).tap { it.figure = "female" }.valid?
  end
end
