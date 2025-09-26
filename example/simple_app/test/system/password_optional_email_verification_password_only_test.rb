require "application_system_test_case"

class PasswordOptionalEmailVerificationPasswordOnlyTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    @prev_flash = Searls::Auth.config.flash_notice_after_email_verified

    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.email_verification_mode = :optional
      config.flash_notice_after_email_verified = "Email verified"
    end
  end

  teardown do
    Searls::Auth.configure do |config|
      config.auth_methods = @prev_methods
      config.email_verification_mode = @prev_mode
      config.flash_notice_after_email_verified = @prev_flash
    end
  end

  def test_registration_sends_verification_email_even_without_email_login
    visit searls_auth.register_path
    fill_in :email, with: "password-only@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "sekrit"
    click_button "Register"

    assert_text "You are now logged in"
    assert_equal 1, ActionMailer::Base.deliveries.size

    mail = ActionMailer::Base.deliveries.last
    assert_equal "Verify your email", mail.subject
    body = mail.html_part&.body&.decoded || mail.body.decoded
    assert_includes body, "Verify email address"

    verification_path = extract_verification_path(mail)
    assert_includes verification_path, "/auth/email/verify"

    visit verification_path

    assert_text "Email verified"
    assert User.find_by(email: "password-only@example.com").email_verified_at.present?
  end

  private

  def extract_verification_path(mail)
    body = mail.html_part&.body&.decoded || mail.body.decoded
    match = body.match(/http[^"\s]+email\/verify[^"\s]*/)
    return unless match

    uri = URI.parse(CGI.unescapeHTML(match[0]))
    uri.request_uri
  end
end
