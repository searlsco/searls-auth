module Searls
  module Auth
    class AuthenticatesUser
      Result = Struct.new(:success?, :user, keyword_init: true)

      def authenticate_by_short_code(short_code, session)
        user = Searls::Auth.config.user_finder_by_id.call(session[:email_auth_short_code_user_id])

        if session[:email_auth_short_code_generated_at].present? &&
            Time.zone.parse(session[:email_auth_short_code_generated_at]) > Searls::Auth.config.token_expiry_minutes.minutes.ago &&
            user.present? &&
            short_code == session[:email_auth_short_code]
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
    end
  end
end
