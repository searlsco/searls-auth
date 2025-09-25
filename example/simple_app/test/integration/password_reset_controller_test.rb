require "test_helper"

class PasswordResetControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    current = Searls::Auth.config
    @previous_config = {
      auth_methods: current.auth_methods,
      password_reset_token_generator: current.password_reset_token_generator,
      password_reset_token_finder: current.password_reset_token_finder,
      before_password_reset: current.before_password_reset,
      auto_login_after_password_reset: current.auto_login_after_password_reset,
      password_reset_enabled: current.password_reset_enabled,
      email_otp_expiry_minutes: current.email_otp_expiry_minutes
    }

    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.password_reset_token_generator = Searls::Auth::DEFAULT_CONFIG[:password_reset_token_generator]
      config.password_reset_token_finder = Searls::Auth::DEFAULT_CONFIG[:password_reset_token_finder]
      config.auto_login_after_password_reset = true
    end

    ActionMailer::Base.deliveries.clear
    @user = User.create!(email: "forgetful@example.com", password: "sekrit")
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs

    Searls::Auth.configure do |config|
      config.auth_methods = @previous_config[:auth_methods]
      config.password_reset_token_generator = @previous_config[:password_reset_token_generator]
      config.password_reset_token_finder = @previous_config[:password_reset_token_finder]
      config.before_password_reset = @previous_config[:before_password_reset]
      config.auto_login_after_password_reset = @previous_config[:auto_login_after_password_reset]
      config.password_reset_enabled = @previous_config[:password_reset_enabled]
      config.email_otp_expiry_minutes = @previous_config[:email_otp_expiry_minutes]
    end

    User.delete_all
  end

  def test_request_form_redirects_when_password_disabled
    Searls::Auth.configure do |config|
      config.auth_methods = [:email_link]
    end

    get searls_auth.password_reset_request_path

    assert_redirected_to searls_auth.login_path
    assert flash[:alert].present?
  end

  def test_request_form_redirects_when_password_reset_disabled
    Searls::Auth.configure do |config|
      config.password_reset_enabled = false
    end

    get searls_auth.password_reset_request_path

    assert_redirected_to searls_auth.login_path
    assert flash[:alert].present?
  end

  def test_request_form_renders_successfully_when_enabled
    get searls_auth.password_reset_request_path
    assert_response :success
    assert_includes response.body, "Forgot your password?"
  end

  def test_request_create_sends_email_for_known_user
    perform_enqueued_jobs do
      post searls_auth.password_reset_request_path, params: {email: @user.email}
    end

    assert_redirected_to searls_auth.password_reset_request_path(email: @user.email)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_request_create_does_not_disclose_unknown_email
    perform_enqueued_jobs do
      post searls_auth.password_reset_request_path, params: {email: "nobody@example.com"}
    end

    assert_redirected_to searls_auth.password_reset_request_path(email: "nobody@example.com")
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert flash[:notice].present?
  end

  def test_edit_redirects_when_token_invalid
    get searls_auth.password_reset_edit_path(token: "nope")
    assert_redirected_to searls_auth.password_reset_request_path
    assert flash[:alert].present?
  end

  def test_edit_renders_when_token_valid
    token = Searls::Auth.config.password_reset_token_generator.call(@user)
    get searls_auth.password_reset_edit_path(token: token)
    assert_response :success
    assert_includes response.body, @user.email
  end

  def test_update_changes_password_and_signs_in
    token = Searls::Auth.config.password_reset_token_generator.call(@user)

    patch searls_auth.password_reset_update_path, params: {
      token: token,
      password: "changed",
      password_confirmation: "changed"
    }

    assert_redirected_to Rails.application.routes.url_helpers.root_path
    assert_equal @user.id, session[:user_id]
    assert @user.reload.authenticate("changed")
    assert flash[:notice].present?
  end

  def test_update_with_mismatched_passwords_rerenders_form
    token = Searls::Auth.config.password_reset_token_generator.call(@user)

    patch searls_auth.password_reset_update_path, params: {
      token: token,
      password: "alpha",
      password_confirmation: "beta"
    }

    assert_response :unprocessable_content
    assert_includes response.body, Searls::Auth.config.resolve(:flash_error_after_password_reset_password_mismatch, {})
    assert @user.reload.authenticate("sekrit")
  end

  def test_before_password_reset_hook_can_cancel_request
    attempts = 0
    Searls::Auth.configure do |config|
      config.before_password_reset = ->(user, params, controller) do
        attempts += 1
        false
      end
    end

    perform_enqueued_jobs do
      post searls_auth.password_reset_request_path, params: {email: @user.email}
    end

    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_equal 1, attempts
  end
end
