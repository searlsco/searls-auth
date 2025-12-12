require_relative "auth/authenticates_user"
require_relative "auth/parses_time_safely"
require_relative "auth/config"
require_relative "auth/builds_target_redirect_url" if defined?(Rails)
require_relative "auth/creates_user" if defined?(Rails)
require_relative "auth/emails_link"
require_relative "auth/emails_verification"
require_relative "auth/engine" if defined?(Rails)
require_relative "auth/railtie" if defined?(Rails)
require_relative "auth/resets_session"
require_relative "auth/delivers_password_reset"
require_relative "auth/resets_password"
require_relative "auth/updates_settings"
require_relative "auth/version"

module Searls
  module Auth
    class Error < StandardError; end

    DEFAULT_CONFIG = {
      auth_methods: [:email_link, :email_otp],
      email_verification_mode: :none,
      # Data setup
      user_finder_by_email: ->(email) { User.find_by(email:) },
      user_finder_by_email_for_registration: ->(email) { User.find_by(email:) },
      user_finder_by_id: ->(id) { User.find_by(id:) },
      user_finder_by_token: ->(token) { User.find_by_token_for(:email_auth, token) },
      user_initializer: ->(params) { User.new(email: params[:email]) },
      existing_user_registration_blocked_predicate: ->(_user, _params) { true },
      user_name_method: "name",
      token_generator: ->(user) { user.generate_token_for(:email_auth) },
      email_otp_expiry_minutes: 30,
      password_verifier: ->(user, password) { user.authenticate(password) },
      password_setter: ->(user, password) { user.password = password },
      password_reset_token_generator: ->(user) { user.generate_token_for(:password_reset) },
      password_reset_token_finder: ->(token) { User.find_by_token_for(:password_reset, token) },
      before_password_reset: ->(user, params, controller) { true },
      password_reset_enabled: true,
      email_verified_predicate: ->(user) { user.respond_to?(:email_verified_at) && user.email_verified_at.present? },
      email_verified_setter: ->(user, time = Time.current) { user.respond_to?(:email_verified_at) ? user.update!(email_verified_at: time) : true },
      password_present_predicate: ->(user) { user.respond_to?(:password_digest) && user.password_digest.present? },
      # Controller setup
      preserve_session_keys_after_logout: [],
      max_allowed_email_otp_attempts: 10,
      # View setup
      layout: "application",
      register_view: "searls/auth/registrations/show",
      login_view: "searls/auth/logins/show",
      verify_view: "searls/auth/verifications/show",
      pending_email_verification_view: "searls/auth/registrations/pending_email_verification",
      password_reset_request_view: "searls/auth/requests_password_resets/show",
      password_reset_edit_view: "searls/auth/resets_passwords/show",
      mail_layout: "searls/auth/layouts/mailer",
      mail_login_template_path: "searls/auth/login_link_mailer",
      mail_login_template_name: "login_link",
      mail_password_reset_template_path: "searls/auth/password_reset_mailer",
      mail_password_reset_template_name: "password_reset",
      mail_email_verification_template_path: "searls/auth/email_verification_mailer",
      mail_email_verification_template_name: "verification_email",
      # Route setup
      redirect_path_after_register: ->(user, params, request, routes) {
        # Not every app defines a root_path, so guarding here:
        routes.respond_to?(:root_path) ? routes.root_path : "/"
      },
      redirect_path_after_login: ->(user, params, request, routes) {
        # Not every app defines a root_path, so guarding here:
        routes.respond_to?(:root_path) ? routes.root_path : "/"
      },
      redirect_path_after_settings_change: ->(user, params, request, routes) {
        routes.respond_to?(:edit_settings_path) ? routes.edit_settings_path : "/settings"
      },
      # Hook setup
      validate_registration: ->(user, params, errors) { errors },
      after_login_success: ->(user) {},
      # Branding setup
      app_name: nil,
      app_url: nil,
      email_background_color: "#d8d7ed",
      email_button_color: "#c664f3",
      email_banner_image_path: nil,
      # Messages setup
      flash_notice_after_registration: ->(user, params) { "Verification email sent to #{params[:email]}" },
      flash_error_after_register_attempt: ->(error_messages, login_path, params) { error_messages },
      flash_notice_after_login_attempt: ->(user, params) { "Login details sent to #{params[:email]}" },
      flash_error_after_login_attempt_unknown_email: ->(register_path, params) {
        "We don't know that email. <a href=\"#{register_path}\">Sign up</a> instead?"
      },
      flash_error_after_login_attempt_invalid_password: ->(params) { "Invalid password. Try again?" },
      flash_error_after_login_attempt_unverified_email: ->(resend_path, params) {
        "You must verify your email before logging in. <a href=\"#{resend_path}\" data-turbo-method=\"patch\">Resend verification email</a>"
      },
      flash_notice_after_login_with_unverified_email: ->(resend_path, params) {
        "You are now logged in, but your email is still unverified. <a href=\"#{resend_path}\" data-turbo-method=\"patch\">Resend verification email</a>"
      },
      flash_error_after_password_misconfigured: ->(params) {
        "Password authentication misconfigured. Add `bcrypt` to your Gemfile or override password hooks."
      },
      flash_error_after_password_reset_token_invalid: ->(params) { "That password reset link is no longer valid. Try again?" },
      flash_error_after_password_reset_password_mismatch: ->(params) { "Passwords must match. Try again?" },
      flash_error_after_password_reset_password_blank: ->(params) { "Password can't be blank. Try again?" },
      flash_error_after_password_reset_not_enabled: ->(params) { "Password resets are unavailable." },
      flash_notice_after_logout: "You've been logged out",
      flash_notice_after_login: "You are now logged in",
      flash_notice_after_verification_email_resent: "Verification email sent",
      flash_notice_after_email_verified: "Email verified",
      flash_notice_after_password_reset_email: ->(params) { "If that email exists, password reset instructions are on the way." },
      flash_notice_after_password_reset: ->(user, params) { "Your password has been reset." },
      flash_error_after_verify_attempt_exceeds_limit: "Too many verification attempts. Please login again to generate a new code",
      flash_error_after_verify_attempt_incorrect_email_otp: "We weren't able to log you in with that code. Try again?",
      flash_error_after_verify_attempt_invalid_link: "We weren't able to log you in with that link. Try again?",
      flash_notice_after_settings_update: ->(user, params) { "Settings updated." },
      flash_error_after_settings_current_password_missing: ->(params) { "Enter your current password to make changes." },
      flash_error_after_settings_current_password_invalid: ->(params) { "That current password doesn't match our records." },
      auto_login_after_password_reset: true

    }.freeze

    C_O_N_F_I_G__D_O_N_T_R_E_F_E_R_E_N_C_E__T_H_I_S__D_I_R_E_C_T_L_Y_L_O_L = Config.new(**DEFAULT_CONFIG)
    def self.configure
      yield C_O_N_F_I_G__D_O_N_T_R_E_F_E_R_E_N_C_E__T_H_I_S__D_I_R_E_C_T_L_Y_L_O_L
      C_O_N_F_I_G__D_O_N_T_R_E_F_E_R_E_N_C_E__T_H_I_S__D_I_R_E_C_T_L_Y_L_O_L.validate!
      C_O_N_F_I_G__D_O_N_T_R_E_F_E_R_E_N_C_E__T_H_I_S__D_I_R_E_C_T_L_Y_L_O_L
    end

    def self.config
      C_O_N_F_I_G__D_O_N_T_R_E_F_E_R_E_N_C_E__T_H_I_S__D_I_R_E_C_T_L_Y_L_O_L.dup.freeze
    end
  end
end
