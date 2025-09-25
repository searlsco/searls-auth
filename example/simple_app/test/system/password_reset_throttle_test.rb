require "application_system_test_case"
require "concurrent-ruby"
require "timeout"

class PasswordResetThrottleTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_hook = Searls::Auth.config.before_password_reset
    @prev_auto_login = Searls::Auth.config.auto_login_after_password_reset

    hook_counter = Concurrent::AtomicFixnum.new(0)

    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.auto_login_after_password_reset = false
      config.before_password_reset = ->(user, params, controller) do
        hook_counter.increment == 1
      end
    end

    @hook_counter = hook_counter
    @user = User.create!(email: "throttle@example.com", password: "sekrit")
  end

  teardown do
    Searls::Auth.configure do |config|
      config.auth_methods = @prev_methods
      config.before_password_reset = @prev_hook
      config.auto_login_after_password_reset = @prev_auto_login
    end
  end

  def test_hook_blocks_second_request
    visit searls_auth.login_path
    click_link "Forgot your password?"
    fill_in "Email address", with: @user.email

    click_button "Send reset instructions"

    wait_until { @hook_counter.value >= 1 }
    assert_equal 1, @hook_counter.value
    wait_until { ActionMailer::Base.deliveries.any? }

    first_mail = ActionMailer::Base.deliveries.last
    assert_not_nil first_mail
    assert_includes Array(first_mail.to), @user.email

    ActionMailer::Base.deliveries.clear

    visit searls_auth.password_reset_request_path
    fill_in "Email address", with: @user.email

    click_button "Send reset instructions"

    wait_until { @hook_counter.value >= 2 }
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  private

  def wait_until(timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop do
        break if yield
        sleep 0.05
      end
    end
  end
end
