require "application_system_test_case"
require "securerandom"

class EmailOnlyRegistrationTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    @prev_initializer = Searls::Auth.config.user_initializer

    Searls::Auth.configure do |config|
      config.auth_methods = [:email_link, :email_otp]
      config.email_verification_mode = :optional
      config.user_initializer = ->(params) {
        generated_password = SecureRandom.base58(12)
        User.new(
          email: params[:email],
          password: generated_password,
          password_confirmation: generated_password
        )
      }
    end

    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Searls::Auth.configure do |config|
      config.auth_methods = @prev_methods
      config.email_verification_mode = @prev_mode
      config.user_initializer = @prev_initializer
    end
  end

  def test_registration_requires_email_login_follow_up
    visit searls_auth.register_path
    fill_in :email, with: "link-only@example.com"
    click_button "Register"

    assert_text "Check your email!"
    assert_equal 1, ActionMailer::Base.deliveries.size

    mail = ActionMailer::Base.deliveries.last
    subject = mail.subject
    assert_includes subject, "login"

    verification_path = extract_verification_path(mail)
    visit verification_path
    assert_text "You are now logged in"
  end

  private

  def extract_verification_path(mail)
    body = mail.html_part&.body&.decoded || mail.body.decoded
    match = body.match(/http[^"\s]+verify_token[^"\s]*/)
    raise "verification link missing" unless match

    uri = URI.parse(CGI.unescapeHTML(match[0]))
    uri.request_uri
  end
end
