require "application_system_test_case"

class EmailOtpAttemptLimitTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_max_attempts = Searls::Auth.config.max_allowed_email_otp_attempts

    Searls::Auth.configure do |c|
      c.auth_methods = [:email_otp]
      c.max_allowed_email_otp_attempts = 2
    end

    @user = User.create!(email: "limit@example.com", password: "sekrit")
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.max_allowed_email_otp_attempts = @prev_max_attempts
    end
  end

  def test_exceeding_otp_attempt_limit_blocks_and_shows_message
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    click_button "Log in"
    assert_text "Check your email!"

    mail = ActionMailer::Base.deliveries.last
    code = mail.subject[/\b(\d{6})\b/, 1]
    assert code
    bad = wrong_code(code)

    # 1st wrong attempt
    fill_in :short_code, with: bad
    click_button "Log in"
    assert_text "We weren't able to log you in with that code"

    # 2nd wrong attempt
    fill_in :short_code, with: bad
    click_button "Log in"
    assert_text "We weren't able to log you in with that code"

    # 3rd attempt exceeds max (2) → lockout
    fill_in :short_code, with: bad
    click_button "Log in"
    assert_current_path searls_auth.login_path, ignore_query: true
    assert_text "Too many verification attempts"
  end

  private

  def wrong_code(code)
    (code == "123456") ? "654321" : "123456"
  end
end
