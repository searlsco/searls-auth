module Searls
  module Auth
    class EmailsVerification
      def email(user:, redirect_path: nil, redirect_subdomain: nil, redirect_host: nil)
        EmailVerificationMailer.with(
          user:,
          token: generate_token!(user),
          redirect_path:,
          redirect_subdomain:,
          redirect_host:
        ).verification_email.deliver_later
      end

      private

      def generate_token!(user)
        Searls::Auth.config.token_generator.call(user)
      rescue KeyError => e
        raise Error, <<~MSG
          Secure token generation for user failed!

          Message: #{e.message}
          User: #{user.inspect}

          This can probably be fixed by adding a line like this to your #{user.class.name} class:

            generates_token_for :email_auth, expires_in: 30.minutes

          Otherwise, you may want to override searls-auth's "token_generator" setting with a proc of your own.
        MSG
      end
    end
  end
end
