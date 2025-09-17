require "application_system_test_case"
require "cgi"
require "uri"

class PasswordResetFlowTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_auto_login = Searls::Auth.config.auto_login_after_password_reset
    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.auto_login_after_password_reset = true
    end
    ActionMailer::Base.deliveries.clear
    @user = User.create!(email: "flow@example.com", password: "sekrit")
  end

  teardown do
    Searls::Auth.configure do |config|
      config.auth_methods = @prev_methods
      config.auto_login_after_password_reset = @prev_auto_login
    end
    ActionMailer::Base.deliveries.clear
  end

  def test_full_password_reset_flow
    redirect_target = only_members_path

    visit searls_auth.login_path(redirect_path: redirect_target)
    assert_includes current_url, "redirect_path=%2Fonly_members"

    click_link "Forgot your password?"
    assert_includes current_url, "redirect_path=%2Fonly_members"

    hidden_redirect_value = find("input[name='redirect_path']", visible: false).value
    assert_equal redirect_target, hidden_redirect_value

    fill_in "Email address", with: @user.email
    click_button "Send reset instructions"
    assert_text "If that email exists"

    reset_url = extract_reset_url(ActionMailer::Base.deliveries.last)
    assert_includes reset_url, "redirect_path=%2Fonly_members"

    visit reset_url
    fill_in "New password", with: "newsecret"
    fill_in "Confirm new password", with: "newsecret"
    click_button "Update password"
    assert_current_path redirect_target, ignore_query: true
    assert_text "Your password has been reset."

    visit reset_url
    assert_text "That password reset link is no longer valid"

    visit searls_auth.login_path(redirect_path: redirect_target)
    fill_in :email, with: @user.email
    fill_in :password, with: "newsecret"
    click_button "Log in"
    assert_current_path redirect_target, ignore_query: true
    assert_text "You are now logged in"
  end

  private

  def extract_reset_url(mail)
    body = mail.html_part&.body&.decoded || mail.body.decoded
    match = body.match(/http[^\s"]+password\/reset\/edit[^\s"]+/)
    return unless match

    uri = URI.parse(CGI.unescapeHTML(match[0]))
    uri.request_uri
  end
end
