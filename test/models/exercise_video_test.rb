require "test_helper"

class ExerciseVideoTest < ActiveSupport::TestCase
  teardown { Exercise.reload! }

  test "prefers the chosen figure, falls back to the single render, else nil" do
    ex = Exercise.all.first
    Exercise.instance_variable_set(:@videos, Set["female/#{ex.slug}", ex.slug])
    assert_equal "/videos/female/#{ex.slug}", ex.video("female")
    assert_equal "/videos/#{ex.slug}", ex.video("male")
    Exercise.instance_variable_set(:@videos, Set[])
    assert_nil ex.video("female")
    assert_nil ex.to_player("female")[:video]
  end

  test "users pick a known figure" do
    assert_not users(:one).tap { it.figure = "robot" }.valid?
    assert users(:one).tap { it.figure = "female" }.valid?
  end
end
