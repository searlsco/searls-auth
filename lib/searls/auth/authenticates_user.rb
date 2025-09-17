module Searls
  module Auth
    class AuthenticatesUser
      Result = Struct.new(:success?, :user, :exceeded_short_code_attempt_limit?, :email_unverified?, keyword_init: true)

      def authenticate_by_short_code(short_code, session)
        if session[:searls_auth_short_code_verification_attempts] > Searls::Auth.config.max_allowed_short_code_attempts
          return Result.new(success?: false, exceeded_short_code_attempt_limit?: true)
        end

        if session[:searls_auth_short_code_generated_at].present? &&
            Time.zone.parse(session[:searls_auth_short_code_generated_at]) > Searls::Auth.config.token_expiry_minutes.minutes.ago &&
            short_code == session[:searls_auth_short_code] &&
            (user = Searls::Auth.config.user_finder_by_id.call(session[:searls_auth_short_code_user_id])).present?
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

        if requires_verification? && !Searls::Auth.config.email_verified_predicate.call(user)
          return Result.new(success?: false, email_unverified?: true)
        end

        return Result.new(success?: false) if !user.respond_to?(:password_digest) || user.password_digest.blank?

        begin
          ok = Searls::Auth.config.password_verifier.call(user, password)
        rescue NameError
          return Result.new(success?: false) # controller will map to misconfiguration message
        end

        if ok
          Searls::Auth.config.after_login_success&.call(user)
          Result.new(success?: true, user: user)
        else
          Result.new(success?: false)
        end
      end

      private

      def requires_verification?
        Searls::Auth.config.email_verification_mode.to_sym == :required
      end
    end
  end
end
