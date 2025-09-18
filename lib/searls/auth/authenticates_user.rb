module Searls
  module Auth
    class AuthenticatesUser
      Result = Struct.new(:success?, :user, :exceeded_email_otp_attempt_limit?, :email_unverified?, keyword_init: true)

      def authenticate_by_email_otp(email_otp, session)
        if session[:searls_auth_email_otp_verification_attempts] > Searls::Auth.config.max_allowed_email_otp_attempts
          return Result.new(success?: false, exceeded_email_otp_attempt_limit?: true)
        end

        generated_at_value = session[:searls_auth_email_otp_generated_at]
        if generated_at_value.present? &&
            (generated_at = parse_otp_timestamp(generated_at_value)) &&
            generated_at > email_otp_expiry_cutoff &&
            email_otp == session[:searls_auth_email_otp] &&
            (user = Searls::Auth.config.user_finder_by_id.call(session[:searls_auth_email_otp_user_id])).present?
          Searls::Auth.config.after_login_success&.call(user)
          Result.new(success?: true, user: user)
        else
          Result.new(success?: false)
        end
      end

      def authenticate_by_token(token)
        user = Searls::Auth.config.user_finder_by_token.call(token)

        if user.present?
          Searls::Auth.config.after_login_success&.call(user)
          Result.new(success?: true, user: user)
        else
          Result.new(success?: false)
        end
      end

      def authenticate_by_password(email, password, session)
        user = Searls::Auth.config.user_finder_by_email.call(email)
        return Result.new(success?: false) if user.blank?

        configuration = Searls::Auth.config

        if requires_verification?(configuration) && !configuration.email_verified_predicate.call(user)
          return Result.new(success?: false, email_unverified?: true)
        end

        begin
          ok = configuration.password_verifier.call(user, password)
        rescue NameError
          return Result.new(success?: false) # controller will map to misconfiguration message
        end

        if ok
          configuration.after_login_success&.call(user)
          Result.new(success?: true, user: user)
        else
          Result.new(success?: false)
        end
      end

      private

      def requires_verification?(configuration)
        value = configuration.email_verification_mode
        value.respond_to?(:to_sym) && value.to_sym == :required
      end

      def email_otp_expiry_cutoff
        minutes = Searls::Auth.config.email_otp_expiry_minutes.to_i
        Time.zone.now - (minutes * 60)
      end

      def parse_otp_timestamp(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
