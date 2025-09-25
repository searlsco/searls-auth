require "application_system_test_case"

class PasswordOnlyTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :none
    end
    @user = User.create!(email: "elaine@example.com", password: "sekrit")
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_login_happy_path_and_no_emails
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    fill_in :password, with: "sekrit"
    click_button "Log in"
    assert_text "You are now logged in"
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_invalid_password
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    fill_in :password, with: "wrong"
    click_button "Log in"
    assert_text "Invalid password"
  end

  def test_no_send_login_email_button
    visit searls_auth.login_path
    refute_button "Send login email"
  end
end
