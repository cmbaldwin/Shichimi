require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  Capybara.register_driver(:shichimi_chrome) do |app|
    opts = Selenium::WebDriver::Chrome::Options.new
    %w[--headless=new --no-sandbox --disable-dev-shm-usage --use-angle=swiftshader --enable-unsafe-swiftshader].each { opts.add_argument(it) }
    # pixelRatio 1: SwiftShader renders the WebGL player in software; at 3x it starves WebDriver.
    opts.add_emulation(device_metrics: { width: 390, height: 844, pixelRatio: 1, touch: true },
                       user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1")
    opts.add_option("goog:loggingPrefs", { browser: "ALL" })
    # eager: Turbo frame navigations with turbo_action "advance" can leave chromedriver waiting on a
    # load that never settles. The read timeout turns any remaining hang into a failure.
    opts.page_load_strategy = :eager
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: opts,
                                        http_client: Selenium::WebDriver::Remote::Http::Default.new(read_timeout: 60))
  end

  driven_by :shichimi_chrome

  setup do
    # Keep CSRF on: the test env disables it, which hid real prod bugs (see slickrock README).
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Workout.sync_catalog!
  end

  teardown do
    assert_no_js_errors
  ensure
    ActionController::Base.allow_forgery_protection = @forgery
  end

  # Real sign-in through the form.
  def sign_in_via_form(user, password: "password")
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button "Sign in"
    assert_no_current_path new_session_path
  end

  # Severe browser console entries since the last check (favicon-style noise excluded).
  def js_errors
    page.driver.browser.logs.get(:browser).select { it.level == "SEVERE" }.map(&:message)
  rescue Selenium::WebDriver::Error::WebDriverError
    []
  end

  def assert_no_js_errors
    errors = js_errors
    assert_empty errors, "JS console errors:\n#{errors.join("\n")}"
  end
end
