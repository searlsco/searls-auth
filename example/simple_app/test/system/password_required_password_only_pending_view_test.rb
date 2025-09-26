require "application_system_test_case"

class PasswordRequiredPasswordOnlyPendingViewTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :required
    end
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_registration_shows_pending_and_can_resend
    visit searls_auth.register_path
    fill_in :email, with: "required-only-pass@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"

    assert_text "Check your email!"
    assert_current_path searls_auth.pending_email_verification_path, ignore_query: true
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Verify your email", ActionMailer::Base.deliveries.first.subject

    click_link "Resend verification email"
    assert_text "Verification email sent"
    assert_current_path searls_auth.pending_email_verification_path, ignore_query: true
  end
end
