require "application_system_test_case"

class ResendVerificationSecurityTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :required
    end

    @user = User.create!(email: "victim@example.com", password: "sekrit")
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_resend_requires_session_context
    # No login and no registration context
    visit searls_auth.resend_email_verification_path(email: @user.email)
    assert_current_path searls_auth.login_path, ignore_query: true
    assert_text "We weren't able to log you in with that link"
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_resend_uses_pending_session_email_not_param
    # Create a pending verification session by registering a different address
    visit searls_auth.register_path
    fill_in :email, with: "owner@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"
    assert_current_path searls_auth.pending_email_verification_path, ignore_query: true
    assert_equal 1, ActionMailer::Base.deliveries.size

    # Now try to force resend to someone else via param
    visit searls_auth.resend_email_verification_path(email: @user.email)
    assert_text "Verification email sent"
    # Without a referrer, controller falls back to the pending view
    assert_current_path searls_auth.pending_email_verification_path, ignore_query: true

    sent_to = ActionMailer::Base.deliveries.last.to
    assert_equal ["owner@example.com"], sent_to
  end
end
