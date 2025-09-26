require "application_system_test_case"

class PasswordVerificationNoneDirectLoginTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :none
    end
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_registration_logs_in_without_double_redirect
    visit searls_auth.register_path
    fill_in :email, with: "direct-login@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"

    assert_text "You are now logged in"
    assert_text "It's member time"
    assert_equal 0, ActionMailer::Base.deliveries.size
  end
end
