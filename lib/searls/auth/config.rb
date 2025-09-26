module Searls
  module Auth
    # Numeric config keys coerced to Integer and required to be > 0
    NUMERIC_FIELDS = [
      :email_otp_expiry_minutes,
      :max_allowed_email_otp_attempts
    ].freeze

    # Core hooks that must always be callable
    HOOK_FIELDS = [
      :user_finder_by_email,
      :user_finder_by_id,
      :user_finder_by_token,
      :user_initializer,
      :token_generator,
      :email_verified_predicate,
      :email_verified_setter,
      :validate_registration,
      :after_login_success
    ].freeze
    Config = Struct.new(
      :auth_methods, # array of symbols, e.g., [:email_link, :email_otp]
      :email_verification_mode, # :none, :optional, :required
      # Data setup
      :user_finder_by_email, # proc(email)
      :user_finder_by_id, # proc(id)
      :user_finder_by_token, # proc(token)
      :user_initializer, # proc(params)
      :user_name_method, # string
      :token_generator, # proc()
      :password_verifier, # proc(user, password)
      :password_setter, # proc(user, password)
      :password_reset_token_generator, # proc(user)
      :password_reset_token_finder, # proc(token)
      :before_password_reset, # proc(user, params, controller)
      :password_reset_enabled, # boolean
      :email_verified_predicate, # proc(user)
      :email_verified_setter, # proc(user, time = Time.current)
      :password_present_predicate, # proc(user)
      # Controller setup
      :preserve_session_keys_after_logout, # array of symbols
      :max_allowed_email_otp_attempts, # integer (email OTP attempts)
      :email_otp_expiry_minutes, # integer
      # View setup
      :layout, # string
      :login_view, # string
      :register_view, # string
      :verify_view, # string
      :pending_email_verification_view, # string
      :password_reset_request_view, # string
      :password_reset_edit_view, # string
      :mail_layout, # string
      :mail_login_template_path, # string
      :mail_login_template_name, # string
      :mail_password_reset_template_path, # string
      :mail_password_reset_template_name, # string
      :mail_email_verification_template_path, # string
      :mail_email_verification_template_name, # string
      # Routing setup
      :redirect_path_after_register, # string or proc(user, params, request, routes), all new registrations redirect here
      :redirect_path_after_login, # string or proc(user, params, request, routes), only redirected here if redirect_path param not set
      :redirect_path_after_settings_change, # string or proc(user, params, request, routes), post-settings updates redirect here
      # Hook setup
      :validate_registration, # proc(user, params, errors = []), must return an array of error messages where empty means valid
      :after_login_success, # proc(user)
      # Branding setup
      :app_name, # string
      :app_url, # string
      :email_banner_image_path, # string
      :email_background_color, # string
      :email_button_color, # string
      # Messages setup
      :flash_notice_after_registration, # string or proc(user, params)
      :flash_error_after_register_attempt, # string or proc(error_messages, login_path, params)
      :flash_notice_after_login_attempt, # string or proc(user, params)
      :flash_error_after_login_attempt_unknown_email, # string or proc(register_path, params)
      :flash_error_after_login_attempt_invalid_password, # string or proc(params)
      :flash_error_after_login_attempt_unverified_email, # string or proc(resend_email_verification_path, params)
      :flash_notice_after_login_with_unverified_email, # string or proc(resend_email_verification_path, params)
      :flash_error_after_password_misconfigured, # string or proc(params)
      :flash_error_after_password_reset_token_invalid, # string or proc(params)
      :flash_error_after_password_reset_password_mismatch, # string or proc(params)
      :flash_error_after_password_reset_password_blank, # string or proc(params)
      :flash_error_after_password_reset_not_enabled, # string or proc(params)
      :flash_notice_after_logout, # string or proc(params)
      :flash_notice_after_login, # string or proc(user, params)
      :flash_notice_after_verification_email_resent, # string or proc(params)
      :flash_notice_after_email_verified, # string or proc(user, params)
      :flash_notice_after_password_reset_email, # string or proc(params)
      :flash_notice_after_password_reset, # string or proc(user, params)
      :flash_error_after_verify_attempt_exceeds_limit, # string or proc(params)
      :flash_error_after_verify_attempt_incorrect_email_otp, # string or proc(params)
      :flash_error_after_verify_attempt_invalid_link, # string or proc(params)
      :flash_notice_after_settings_update, # string or proc(user, params)
      :flash_error_after_settings_current_password_missing, # string or proc(params)
      :flash_error_after_settings_current_password_invalid, # string or proc(params)
      :auto_login_after_password_reset, # boolean
      keyword_init: true
    ) do
      # Get values from values that might be procs
      def resolve(option, *args)
        key = option.to_sym
        value = public_send(key)
        value.respond_to?(:call) ? value.call(*args) : value
      end

      def password_reset_enabled?
        auth_methods.include?(:password) && password_reset_enabled
      end

      def password_present?(user)
        predicate = password_present_predicate
        return false if predicate.nil?

        predicate.call(user)
      end

      def validate!
        validate_auth_methods!
        validate_email_verification_mode!
        validate_password_settings!
        validate_numeric_options!
        validate_core_hooks!
        validate_default_user_hooks!
      end

      private

      def validate_auth_methods!
        normalized = Array(auth_methods).map(&:to_sym)
        self.auth_methods = normalized
        allowed = [:password, :email_link, :email_otp]
        raise Searls::Auth::Error, "auth_methods cannot be empty; enable at least one of :password, :email_link, or :email_otp" if normalized.empty?
        unknown = normalized - allowed
        if unknown.any?
          raise Searls::Auth::Error, "Unknown auth_methods: #{unknown.inspect}. Allowed: #{allowed.inspect}"
        end
      end

      def validate_email_verification_mode!
        mode_value = email_verification_mode
        mode = mode_value.respond_to?(:to_sym) ? mode_value.to_sym : :none
        self.email_verification_mode = mode
        auth_methods
        # Allow email verification regardless of email auth methods; verification emails are separate
      end

      def validate_password_settings!
        methods = auth_methods
        return unless methods.include?(:password)

        using_default_hooks =
          password_verifier.equal?(Searls::Auth::DEFAULT_CONFIG[:password_verifier]) &&
          password_setter.equal?(Searls::Auth::DEFAULT_CONFIG[:password_setter])

        if using_default_hooks && defined?(::User)
          missing = []
          missing << "User#authenticate" unless ::User.method_defined?(:authenticate)
          has_password_digest_method = ::User.method_defined?(:password_digest)
          has_password_digest_column = ::User.respond_to?(:column_names) && ::User.column_names.include?("password_digest")
          missing << "users.password_digest" unless has_password_digest_method || has_password_digest_column
          if missing.any?
            raise Searls::Auth::Error, "Password login requires #{missing.join(" and ")}. Add bcrypt/has_secure_password or override password hooks."
          end
        end

        ensure_callable!(:password_reset_token_generator)
        ensure_callable!(:password_reset_token_finder)
        ensure_callable!(:before_password_reset)
        ensure_callable!(:password_present_predicate)
        self.auto_login_after_password_reset = !!auto_login_after_password_reset
        self.password_reset_enabled = true if password_reset_enabled.nil?
        self.password_reset_enabled = !!password_reset_enabled
      end

      def validate_numeric_options!
        NUMERIC_FIELDS.each do |key|
          raw = public_send(key)
          coerced = begin
            Integer(raw)
          rescue ArgumentError, TypeError
            raise Searls::Auth::Error, "#{key} must be an integer"
          end
          if coerced < 1
            raise Searls::Auth::Error, "#{key} must be >= 1"
          end
          public_send("#{key}=", coerced)
        end
      end

      def validate_core_hooks!
        HOOK_FIELDS.each { |key| ensure_callable!(key) }
      end

      def ensure_callable!(key)
        value = public_send(key)
        return if value.respond_to?(:call)

        raise Searls::Auth::Error, "#{key} must be callable when password authentication is enabled"
      end

      def ensure_callable_optional!(key)
        value = public_send(key)
        return if value.nil? || value.respond_to?(:call)

        raise Searls::Auth::Error, "#{key} must be callable when provided"
      end

      # If any hooks still reference the default `User` implementation, make
      # sure a compatible `User` exists and exposes the fields/methods our
      # defaults assume (id, email, token helpers, etc.).
      def validate_default_user_hooks!
        hooks_pointing_at_user = [
          :user_finder_by_email,
          :user_finder_by_id,
          :user_finder_by_token,
          :user_initializer,
          :token_generator
        ].select { |k| public_send(k).equal?(Searls::Auth::DEFAULT_CONFIG[k]) }

        return if hooks_pointing_at_user.empty?

        # Enforce these checks only when ActiveModel is present (e.g., Rails).
        return unless defined?(::ActiveModel)

        unless defined?(::User)
          raise Searls::Auth::Error,
            "Default hooks assume a `User` model. Define `User` (Active Record/Active Model) or override: #{hooks_pointing_at_user.inspect}"
        end

        # Proceed with concrete, per-hook capability checks.

        # One-off validations for each default hook
        if public_send(:user_finder_by_id).equal?(Searls::Auth::DEFAULT_CONFIG[:user_finder_by_id])
          unless ::User.respond_to?(:find_by)
            raise Searls::Auth::Error, "Default :user_finder_by_id expects User.find_by(id: ...) to exist."
          end
          unless ::User.method_defined?(:id)
            raise Searls::Auth::Error, "Default :user_finder_by_id expects a `User#id` attribute."
          end
        end

        if public_send(:user_finder_by_email).equal?(Searls::Auth::DEFAULT_CONFIG[:user_finder_by_email])
          unless ::User.respond_to?(:find_by)
            raise Searls::Auth::Error, "Default :user_finder_by_email expects User.find_by(email: ...) to exist."
          end
          has_email_method = ::User.method_defined?(:email)
          has_email_column = ::User.respond_to?(:column_names) && ::User.column_names.include?("email")
          unless has_email_method || has_email_column
            raise Searls::Auth::Error, "Default :user_finder_by_email expects a `users.email` attribute."
          end
        end

        if public_send(:user_finder_by_token).equal?(Searls::Auth::DEFAULT_CONFIG[:user_finder_by_token])
          unless ::User.respond_to?(:find_by_token_for)
            raise Searls::Auth::Error, "Default :user_finder_by_token expects User.find_by_token_for(:email_auth, token) (Rails signed_id API)."
          end
        end

        if public_send(:user_initializer).equal?(Searls::Auth::DEFAULT_CONFIG[:user_initializer])
          unless ::User.respond_to?(:new)
            raise Searls::Auth::Error, "Default :user_initializer expects `User.new(email: ...)` to work."
          end
          begin
            probe = ::User.new
            has_email_setter = probe.respond_to?(:email=)
            has_email_column = ::User.respond_to?(:column_names) && ::User.column_names.include?("email")
            unless has_email_setter || has_email_column
              raise Searls::Auth::Error, "Default :user_initializer expects a writable email attribute on User."
            end
          rescue ArgumentError
            # e.g., custom initialize signature
            raise Searls::Auth::Error, "Default :user_initializer expects `User.new` with keyword args to be permissible."
          end
        end

        if public_send(:token_generator).equal?(Searls::Auth::DEFAULT_CONFIG[:token_generator])
          unless ::User.method_defined?(:generate_token_for)
            raise Searls::Auth::Error, "Default :token_generator expects `user.generate_token_for(:email_auth)` (Rails signed_id API)."
          end
        end
      end
    end
  end
end
