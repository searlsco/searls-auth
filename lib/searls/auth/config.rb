module Searls
  module Auth
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
      :token_expiry_minutes, # integer
      :password_verifier, # proc(user, password)
      :password_setter, # proc(user, password)
      :email_verified_predicate, # proc(user)
      :email_verified_setter, # proc(user, time = Time.current)
      # Controller setup
      :preserve_session_keys_after_logout, # array of symbols
      :max_allowed_short_code_attempts, # integer
      # View setup
      :layout, # string
      :login_view, # string
      :register_view, # string
      :verify_view, # string
      :mail_layout, # string
      :mail_login_template_path, # string
      :mail_login_template_name, # string
      # Routing setup
      :redirect_path_after_register, # string or proc(user, params, request, routes), all new registrations redirect here
      :default_redirect_path_after_login, # string or proc(user, params, request, routes), only redirected here if redirect_path param not set
      # Hook setup
      :validate_registration, # proc(user, params, errors = []), must return an array of error messages where empty means valid
      :after_login_success, # proc(user)
      # Branding setup
      :app_name, # string
      :app_url, # string
      :support_email_address, # string
      :email_banner_image_path, # string
      :email_background_color, # string
      :email_button_color, # string
      # Messages setup
      :flash_notice_after_registration, # string or proc(user, params)
      :flash_error_after_register_attempt, # string or proc(error_messages, login_path, params)
      :flash_notice_after_login_attempt, # string or proc(user, params)
      :flash_error_after_login_attempt_unknown_email, # string or proc(register_path, params)
      :flash_error_after_login_attempt_invalid_password, # string or proc(params)
      :flash_error_after_login_attempt_unverified_email, # string or proc(resend_verification_path, params)
      :flash_error_after_password_misconfigured, # string or proc(params)
      :flash_notice_after_logout, # string or proc(params)
      :flash_notice_after_verification, # string or proc(user, params)
      :flash_notice_after_verification_email_resent, # string or proc(params)
      :flash_error_after_verify_attempt_exceeds_limit, # string or proc(params)
      :flash_error_after_verify_attempt_incorrect_short_code, # string or proc(params)
      :flash_error_after_verify_attempt_invalid_link, # string or proc(params)
      keyword_init: true
    ) do
      # Get values from values that might be procs
      def resolve(option, *args)
        if self[option].respond_to?(:call)
          self[option].call(*args)
        else
          self[option]
        end
      end

      def auth_methods
        Array(self[:auth_methods]).map(&:to_sym)
      end

      def validate!
        methods = auth_methods
        if self[:email_verification_mode].to_sym != :none && (methods & [:email_link, :email_otp]).empty?
          raise Searls::Auth::Error, "email_verification_mode is #{self[:email_verification_mode].inspect} but no email auth methods are enabled"
        end

        if methods.include?(:password)
          using_default_hooks =
            self[:password_verifier].equal?(Searls::Auth::DEFAULT_CONFIG[:password_verifier]) &&
            self[:password_setter].equal?(Searls::Auth::DEFAULT_CONFIG[:password_setter])

          if using_default_hooks && defined?(::User)
            missing = []
            missing << "User#authenticate" unless ::User.method_defined?(:authenticate)
            begin
              unless ::User.new.respond_to?(:password_digest)
                missing << "users.password_digest"
              end
            rescue
              # best-effort; ignore
            end
            if missing.any?
              raise Searls::Auth::Error, "Password login requires #{missing.join(" and ")}. Add bcrypt/has_secure_password or override password hooks."
            end
          end
        end
        true
      end
    end
  end
end
