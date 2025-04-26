require_relative "auth/authenticates_user"
require_relative "auth/config"
require_relative "auth/creates_user" if defined?(Rails)
require_relative "auth/emails_link"
require_relative "auth/engine" if defined?(Rails)
require_relative "auth/railtie" if defined?(Rails)
require_relative "auth/resets_session"
require_relative "auth/version"

module Searls
  module Auth
    class Error < StandardError; end

    DEFAULT_CONFIG = {
      # Data setup
      user_finder_by_email: ->(email) { User.find_by(email:) },
      user_finder_by_id: ->(id) { User.find_by(id:) },
      user_finder_by_token: ->(token) { User.find_by_token_for(:email_auth, token) },
      user_initializer: ->(params) { User.new(email: params[:email]) },
      user_name_method: "name",
      token_generator: ->(user) { user.generate_token_for(:email_auth) },
      token_expiry_minutes: 30,
      # Controller setup
      preserve_session_keys_after_logout: [],
      max_allowed_short_code_attempts: 10,
      # View setup
      layout: "application",
      register_view: "searls/auth/registrations/show",
      login_view: "searls/auth/logins/show",
      verify_view: "searls/auth/verifications/show",
      mail_layout: "searls/auth/layouts/mailer",
      mail_login_template_path: "searls/auth/login_link_mailer",
      mail_login_template_name: "login_link",
      # Route setup
      redirect_path_after_register: ->(user, params, request, routes) {
        # Not every app defines a root_path, so guarding here:
        routes.respond_to?(:root_path) ? routes.root_path : "/"
      },
      default_redirect_path_after_login: ->(user, params, request, routes) {
        # Not every app defines a root_path, so guarding here:
        routes.respond_to?(:root_path) ? routes.root_path : "/"
      },
      # Hook setup
      validate_registration: ->(user, params, errors) { errors },
      after_login_success: nil,
      # Branding setup
      app_name: nil,
      app_url: nil,
      support_email_address: nil,
      email_background_color: "#d8d7ed",
      email_button_color: "#c664f3",
      email_banner_image_path: nil,
      # Messages setup
      flash_notice_after_registration: ->(user, params) { "Verification email sent to #{params[:email]}" },
      flash_error_after_register_attempt: ->(error_messages, login_path, params) { error_messages },
      flash_notice_after_login_attempt: ->(user, params) { "Login details sent to #{params[:email]}" },
      flash_error_after_login_attempt_unknown_email: ->(register_path, params) {
        "We don't know that email. <a href=\"#{register_path}\">Sign up</a> instead?".html_safe
      },
      flash_notice_after_logout: "You've been logged out",
      flash_notice_after_verification: "You are now logged in",
      flash_error_after_verify_attempt_exceeds_limit: "Too many verification attempts. Please login again to generate a new code",
      flash_error_after_verify_attempt_incorrect_short_code: "We weren't able to log you in with that code. Try again?",
      flash_error_after_verify_attempt_invalid_link: "We weren't able to log you in with that link. Try again?"

    }.freeze

    CONFIG = Config.new(**DEFAULT_CONFIG)
    def self.configure(&blk)
      yield CONFIG
    end

    def self.config
      CONFIG.dup.freeze
    end
  end
end
