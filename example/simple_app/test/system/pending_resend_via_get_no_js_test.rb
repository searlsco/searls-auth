require "application_system_test_case"

class PendingResendViaGetNoJsTest < ApplicationSystemTestCase
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

  def test_resend_via_get_keeps_you_on_pending
    visit searls_auth.register_path
    fill_in :email, with: "nojs@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"
    assert_current_path searls_auth.pending_email_verification_path, ignore_query: true
    assert_equal 1, ActionMailer::Base.deliveries.size

    # Simulate no-JS GET (no turbo-method patch). Visiting the URL directly
    visit searls_auth.resend_email_verification_path

    assert_text "Verification email sent"
    assert_current_path searls_auth.pending_email_verification_path, ignore_query: true
    assert_equal 2, ActionMailer::Base.deliveries.size
  end
end
