require "test_helper"

class PasswordResetServicesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    current = Searls::Auth.config
    @previous_config = {
      auth_methods: current.auth_methods,
      password_reset_token_generator: current.password_reset_token_generator,
      password_reset_token_finder: current.password_reset_token_finder,
      password_reset_token_clearer: current.password_reset_token_clearer,
      password_reset_expiry_minutes: current.password_reset_expiry_minutes,
      before_password_reset: current.before_password_reset,
      auto_login_after_password_reset: current.auto_login_after_password_reset
    }

    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.password_reset_token_generator = Searls::Auth::DEFAULT_CONFIG[:password_reset_token_generator]
      config.password_reset_token_finder = Searls::Auth::DEFAULT_CONFIG[:password_reset_token_finder]
      config.password_reset_token_clearer = Searls::Auth::DEFAULT_CONFIG[:password_reset_token_clearer]
      config.password_reset_expiry_minutes = 30
      config.auto_login_after_password_reset = true
    end

    ActionMailer::Base.deliveries.clear
    @user = User.create!(email: "reset@example.com", password: "sekrit")
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs

    Searls::Auth.configure do |config|
      config.auth_methods = @previous_config[:auth_methods]
      config.password_reset_token_generator = @previous_config[:password_reset_token_generator]
      config.password_reset_token_finder = @previous_config[:password_reset_token_finder]
      config.password_reset_token_clearer = @previous_config[:password_reset_token_clearer]
      config.password_reset_expiry_minutes = @previous_config[:password_reset_expiry_minutes]
      config.before_password_reset = @previous_config[:before_password_reset]
      config.auto_login_after_password_reset = @previous_config[:auto_login_after_password_reset]
    end

    User.delete_all
  end

  def test_delivers_password_reset_email
    perform_enqueued_jobs do
      Searls::Auth::DeliversPasswordReset.new.deliver(user: @user, redirect_path: "/members", redirect_subdomain: nil)
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.first
    assert_equal [@user.email], mail.to
    assert_includes mail.body.encoded, "Reset password"
  end

  def test_delivers_password_reset_email_with_custom_generator
    Searls::Auth.configure do |config|
      config.password_reset_token_generator = ->(user) { "custom-token-for-#{user.id}" }
    end

    perform_enqueued_jobs do
      Searls::Auth::DeliversPasswordReset.new.deliver(user: @user, redirect_path: nil, redirect_subdomain: nil)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_includes mail.body.encoded, "custom-token-for-#{@user.id}"
  end

  def test_resets_password_successfully
    cleared = []
    Searls::Auth.configure do |config|
      config.password_reset_token_clearer = ->(user) { cleared << user.id }
    end

    result = Searls::Auth::ResetsPassword.new.reset(
      user: @user,
      password: "changeit",
      password_confirmation: "changeit"
    )

    assert result.success?
    assert_equal [@user.id], cleared
    assert @user.reload.authenticate("changeit")
  end

  def test_resets_password_requires_matching_confirmation
    result = Searls::Auth::ResetsPassword.new.reset(
      user: @user,
      password: "alpha",
      password_confirmation: "beta"
    )

    refute result.success?
    assert_includes result.errors, Searls::Auth.config.resolve(:flash_error_after_password_reset_password_mismatch, {})
    assert @user.reload.authenticate("sekrit")
  end

  def test_resets_password_rejects_blank_password
    result = Searls::Auth::ResetsPassword.new.reset(
      user: @user,
      password: "",
      password_confirmation: ""
    )

    refute result.success?
    assert_includes result.errors, Searls::Auth.config.resolve(:flash_error_after_password_reset_password_blank, {})
    assert @user.reload.authenticate("sekrit")
  end
end
