require "application_system_test_case"
require "cgi"
require "uri"

class PasswordVerificationModesTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password, :email_link]
      c.email_verification_mode = :required
    end
    @user = User.create!(email: "kramer@example.com", password: "sekrit")
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
    body = mail.html_part&.body&.decoded || mail.body.decoded
    verification_path = extract_verification_path(body)
    visit verification_path
    assert_text "Email verified"
    assert_text "It's member time"
  end

  private

  def extract_verification_path(body)
    match = body.match(/http[^"\s]+email\/verify[^"\s]*/)
    raise "verification link missing" unless match

    uri = URI.parse(CGI.unescapeHTML(match[0]))
    uri.request_uri
  end
end
