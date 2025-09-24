module Searls
  module Auth
    class EmailVerificationsController < BaseController
      def show
        user = searls_auth_config.user_finder_by_token.call(params[:token])

        if user.present?
          unless searls_auth_config.email_verified_predicate.call(user)
            searls_auth_config.email_verified_setter.call(user)
          end

          flash[:notice] = searls_auth_config.resolve(
            :flash_notice_after_email_verified,
            user,
            params
          )

          redirect_after_login(user)
        else
          flash[:alert] = searls_auth_config.resolve(
            :flash_error_after_verify_attempt_invalid_link,
            params
          )

          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
      end
    end
  end
end
