module Searls
  module Auth
    class DeliversPasswordReset
      Result = Struct.new(:success?, keyword_init: true)

      def deliver(user:, redirect_path: nil, redirect_host: nil)
        token = Searls::Auth.config.password_reset_token_generator.call(user)
        PasswordResetMailer.with(
          user:,
          token:,
          redirect_path:,
          redirect_host:
        ).password_reset.deliver_later
        Result.new(success?: true)
      end
    end
  end
end
