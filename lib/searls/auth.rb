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
      user_initializer: ->(params) { User.new(params[:email]) },
      user_name_field: "name",
      token_generator: ->(user) { user.generate_token_for(:email_auth) },
      token_expiry_minutes: 30,
      # Controller setup
      preserve_session_keys_after_logout: [],
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
      email_banner_image_path: nil
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
