require "application_system_test_case"

class PasswordVerificationModesTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password, :email_link]
      c.email_verification_mode = :required
    end
    @user = User.create!(email: "kramer@example.com", password: "sekrit")
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_block_password_until_verified_and_resend
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    fill_in :password, with: "sekrit"
    click_button "Log in"
    assert_text "You must verify your email"

    click_link "Resend verification email"
    assert_text "Verification email sent"

    mail = ActionMailer::Base.deliveries.last
    body = mail.text_part&.decoded || mail.body.encoded
    token = body.match(/token=([^&\s]+)/)[1]
    visit searls_auth.verify_token_path(token: token)
    assert_text "You are now logged in"
  end
end
