require "application_system_test_case"

class PasswordRequiredModeRegistrationTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password, :email_link]
      c.email_verification_mode = :required
    end
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_registration_sends_verification_and_blocks_login
    visit searls_auth.register_path(redirect_path: "/after", redirect_subdomain: "app")
    fill_in :email, with: "banya@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"
    assert_text "Check your email!"
    assert_current_path searls_auth.pending_email_verification_path(email: "banya@example.com", redirect_path: "/after", redirect_subdomain: "app")
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Verify your email", ActionMailer::Base.deliveries.first.subject
  end
end
