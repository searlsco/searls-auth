require "application_system_test_case"

class ShortCodeLoginTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(email: "jerry@example.com")
  end

  def test_happy_code_path
    attempt_login!
    short_code = check_mail!

    fill_in :short_code, with: wrong_code(short_code)
    click_button "Log in"
    assert_text "We weren't able to log you in with that code. Try again?"
    fill_in :short_code, with: short_code
    click_button "Log in"
    assert_text "You are now logged in"
    click_link "Log out"
    assert_text "You've been logged out"
    find_field :email
    assert_equal "/auth/login", current_path
  end

  def test_too_many_incorrect_short_codes
    attempt_login!
    short_code = check_mail!

    10.times do |i|
      visit current_url
      fill_in :short_code, with: wrong_code(short_code)
      click_button "Log in"
      assert_text "We weren't able to log you in with that code. Try again?"
    end

    visit current_url
    # Even if you're write, you blew it -- too bad, so sad
    fill_in :short_code, with: short_code
    click_button "Log in"
    assert_text "Too many verification attempts. Please login again to generate a new code"
    assert_equal "/auth/login", current_path

    # Be sneaky and try to re-enter anyway, the session should be cleared
    page.go_back
    fill_in :short_code, with: short_code
    click_button "Log in"
    assert_text "We weren't able to log you in with that code. Try again?"
  end

  private

  def attempt_login!
    visit searls_auth.login_path
    fill_in :email, with: @user.email
    click_button "Log in"
    assert_text "Check your email!"
  end

  def check_mail!
    mail = ActionMailer::Base.deliveries.last
    match = mail.subject.match(/Your login code is (\d{6})/)
    assert match, "Expected to find login code in email"
    short_code = match[1]
    assert short_code, "Expected to capture a 6-digit code"
    short_code
  end

  def wrong_code(short_code)
    if short_code == "123456"
      "654321"
    else
      "123456"
    end
  end
end
