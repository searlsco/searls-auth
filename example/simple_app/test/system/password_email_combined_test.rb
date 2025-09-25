require "application_system_test_case"

class PasswordEmailCombinedTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:email_link, :email_otp, :password]
      c.email_verification_mode = :optional
    end
    @user = User.create!(email: "george@example.com", password: "sekrit")
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_password_login_does_not_send_email
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    fill_in :password, with: "sekrit"
    click_button "Log in"
    assert_text "You are now logged in, but your email is still unverified. Resend verification email"
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_send_login_email_path
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    click_button "Send login email"
    assert_text "Check your email!"
    mail = ActionMailer::Base.deliveries.last
    body = mail.text_part&.decoded || mail.body.encoded
    token = body.match(/token=([^&\s]+)/)[1]
    visit searls_auth.verify_token_path(token: token)
    assert_text "You are now logged in"
  end
end
