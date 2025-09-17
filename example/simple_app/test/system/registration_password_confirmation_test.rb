require "application_system_test_case"

class RegistrationPasswordConfirmationTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :none
    end
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_password_confirmation_mismatch_shows_error
    visit searls_auth.register_path
    fill_in :email, with: "newman@example.com"
    fill_in :password, with: "sekrit"
    fill_in :password_confirmation, with: "notthesame"
    click_button "Register"
    assert_current_path searls_auth.register_path
    assert_text "Password confirmation doesn't match Password"
  end
end
