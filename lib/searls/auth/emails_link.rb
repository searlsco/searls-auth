module Searls
  module Auth
    class EmailsLink
      def email(user:, short_code:, redirect_path: nil, redirect_subdomain: nil)
        LoginLinkMailer.with(
          user:,
          token: Searls::Auth.config.token_generator.call(user),
          short_code:,
          redirect_path:,
          redirect_subdomain:
        ).login_link.deliver_later
      end
    end
  end
end
