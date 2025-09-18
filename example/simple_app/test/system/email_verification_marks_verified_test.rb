require "application_system_test_case"

class EmailVerificationMarksVerifiedTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:email_link, :email_otp]
      c.email_verification_mode = :required
    end
    @user = User.create!(email: "puddy@example.com", password: "sekrit")
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_email_verification_sets_email_verified_at
    token = @user.generate_token_for(:email_auth)
    visit searls_auth.verify_token_path(token: token)
    assert_text "You are now logged in"
    assert User.find_by(email: @user.email).email_verified_at.present?
  end
end
