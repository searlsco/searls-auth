require "application_system_test_case"

class EmailDuoTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(email: "jerry@example.com", password: "sekrit")
  end

  def test_default_otp_flow
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    click_button "Log in"
    assert_text "Check your email!"

    mail = ActionMailer::Base.deliveries.last
    code = mail.subject[/\b(\d{6})\b/, 1]
    assert code

    fill_in :short_code, with: wrong_code(code)
    click_button "Log in"
    assert_text "We weren't able to log you in with that code. Try again?"

    fill_in :short_code, with: code
    click_button "Log in"
    assert_text "You are now logged in"

    click_link "Log out"
    assert_text "You've been logged out"
    find_field :email
    assert_equal "/auth/login", current_path
  end

  def test_default_magic_link_flow
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    click_button "Log in"
    assert_text "Check your email!"

    mail = ActionMailer::Base.deliveries.last
    body = mail.text_part&.decoded || mail.body.encoded
    token = body.match(/token=([^&\s]+)/)[1]

    visit searls_auth.verify_token_path(token: token)
    assert_text "You are now logged in"

    click_link "Log out"
    assert_text "You've been logged out"
  end

  def test_link_only_hides_otp_and_logs_in_via_link
    with_auth_methods([:email_link]) do
      visit searls_auth.login_path
      fill_in :email, with: @user.email
      click_button "Log in"
      assert_text "Check your email!"
      refute_selector "input[name=short_code]"

      mail = ActionMailer::Base.deliveries.last
      body = mail.text_part&.decoded || mail.body.encoded
      assert_no_match(/\b\d{6}\b/, mail.subject)
      assert_no_match(/\b\d{6}\b/, body)
      token = body.match(/token=([^&\s]+)/)[1]
      visit searls_auth.verify_token_path(token: token)
      assert_text "You are now logged in"
    end
  end

  def test_otp_only_happy_path_and_no_link
    with_auth_methods([:email_otp]) do
      visit searls_auth.login_path
      fill_in :email, with: @user.email
      click_button "Log in"
      assert_text "Check your email!"
      assert_selector "input[name=short_code]"

      mail = ActionMailer::Base.deliveries.last
      body = mail.text_part&.decoded || mail.body.encoded
      assert_match(/\b\d{6}\b/, mail.subject)
      assert_no_match(/verify_token\?token=/, body)

      code = mail.subject[/\b(\d{6})\b/, 1]
      fill_in :short_code, with: code
      click_button "Log in"
      assert_text "You are now logged in"
    end
  end

  def test_otp_only_rejects_magic_link
    with_auth_methods([:email_otp]) do
      visit searls_auth.verify_token_path(token: "not-a-real-token")
      assert_current_path searls_auth.login_path
      assert_text "We weren't able to log you in with that link. Try again?"
    end
  end

  private

  def with_auth_methods(methods)
    prev = Searls::Auth.config.auth_methods
    Searls::Auth.configure { |c| c.auth_methods = methods }
    yield
  ensure
    Searls::Auth.configure { |c| c.auth_methods = prev }
  end

  def wrong_code(code)
    (code == "123456") ? "654321" : "123456"
  end
end
