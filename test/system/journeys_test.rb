require "application_system_test_case"

class JourneysTest < ApplicationSystemTestCase
  test "sign up lands on Today" do
    visit new_registration_path
    fill_in "user_name", with: "Hana"
    fill_in "user_email_address", with: "hana@example.com"
    fill_in "user_password", with: "sevenminutes"
    fill_in "user_password_confirmation", with: "sevenminutes"
    click_button "Create account"
    assert_current_path root_path
    assert_text "Hana"
    assert_text "day streak"
    assert_no_js_errors
  end

  test "browse library with filters, add to routine" do
    sign_in_via_form users(:one)
    visit workouts_path
    total = all(".wcard").size
    assert_operator total, :>, 5
    # Set via JS: clicking an <option> under touch emulation opens Chrome's native picker, which wedges WebDriver.
    execute_script("const s = document.querySelector('select#fmt'); s.selectedIndex = 3; s.dispatchEvent(new Event('change', { bubbles: true }))")
    assert_selector "turbo-frame#results"
    assert_no_selector ".wcard", count: total
    assert_operator all(".wcard").size, :>, 0
    first(".wcard").click
    assert_selector "h1"
    name = find("h1").text
    click_button "Add to routine"
    assert_text "In your routine"
    visit routine_items_path
    assert_link name
    assert_no_js_errors
  end

  test "play a workout to the end, rate it, see it in history and stats" do
    sign_in_via_form users(:one)
    w = Workout.catalog.first
    visit play_workout_path(w, autostart: 1, seek: w.timeline.sum { it[:seconds] } - 3)
    assert_text "Nice work", wait: 20 # the player's finish submits the log form
    click_button "Hard+"
    assert_text "currently 6"
    visit workout_logs_path
    assert_text w.name
    assert_text "RPE 6"
    visit stats_path
    assert_selector "h1"
    assert_no_js_errors
  end

  test "start button runs the player" do
    sign_in_via_form users(:one)
    visit play_workout_path(Workout.catalog.first)
    click_button "Start"
    assert_text "WORK", wait: 15
    click_button "End"
    assert_no_js_errors
  end

  test "build, edit and delete a custom workout" do
    sign_in_via_form users(:one)
    visit new_workout_path
    fill_in "workout_name", with: "Mine Alpha"
    cats = Exercise.all.group_by(&:category)
    picks = cats.values.map(&:first)
    all("select[name='workout[exercise_slugs][]']").each_with_index do |sel, i|
      sel.find("option[value='#{picks[i % picks.size].slug}']").select_option
    end
    click_button "Create Workout"
    assert_text "Mine Alpha"
    assert_text "Workout saved."
    click_link "Edit"
    fill_in "workout_name", with: "Mine Beta"
    click_button "Update Workout"
    assert_text "Workout updated."
    assert_selector "h1", text: "Mine Beta"
    accept_confirm { click_button "Delete" }
    assert_text "Workout deleted."
    assert_no_text "Mine Beta"
    assert_nil Workout.find_by(name: "Mine Beta")
  end

  test "settings persist" do
    user = users(:one)
    sign_in_via_form user
    visit settings_path
    check "user_reminders_enabled"
    fill_in "user_reminder_time", with: "07:45"
    %w[0 1 2 3 4 5 6].each { uncheck "day_#{it}" }
    check "day_1"
    check "day_3"
    click_button "Save"
    assert_text "Settings saved."
    user.reload
    assert_equal "07:45", user.reminder_time
    assert_equal "13", user.reminder_days
    assert_checked_field "day_3"
    assert_unchecked_field "day_2"
    assert_equal "07:45", find("#user_reminder_time").value
  end

  test "signed-out pages render" do
    visit root_path
    assert_selector "body"
    assert_no_js_errors
    visit exercises_path
    assert_selector ".ex-card"
    assert_no_js_errors
    visit science_path
    assert_selector "h1"
    assert_no_js_errors
    visit exercise_path(Exercise.all.first)
    assert_selector "canvas.ex-figure"
    sleep 1 # let the WebGL figure render a few frames
    assert_no_js_errors
  end
end
