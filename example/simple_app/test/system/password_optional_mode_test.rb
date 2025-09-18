require "application_system_test_case"

class PasswordOptionalModeTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password, :email_link]
      c.email_verification_mode = :optional
    end
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_registration_sends_verification_email_and_logs_in
    visit searls_auth.register_path
    fill_in :email, with: "peterman@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"
    assert_text "You are now logged in"
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_unverified_user_can_still_login_with_password
    user = User.create!(email: "sue@example.com", password: "sekrit")
    visit searls_auth.login_path
    fill_in :email, with: user.email
    fill_in :password, with: "sekrit"
    click_button "Log in"
    assert_text "You are now logged in"
  end
end
