module Searls
  module Auth
    class LoginsController < BaseController
      before_action :reset_expired_short_code

      def show
        render searls_auth_config.login_view, layout: searls_auth_config.layout
      end

      def create
        user = searls_auth_config.user_finder_by_email.call(params[:email])

        if user.present?
          if searls_auth_config.auth_methods.include?(:email_otp)
            attach_short_code_to_session!(user)
          else
            clear_short_code_from_session!
          end

          EmailsLink.new.email(
            user:,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain],
            short_code: session[:searls_auth_short_code]
          )
          flash[:notice] = searls_auth_config.resolve(
            :flash_notice_after_login_attempt,
            user, params
          )
          redirect_to searls_auth.verify_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        else
          flash.now[:error] = searls_auth_config.resolve(
            :flash_error_after_login_attempt_unknown_email,
            searls_auth.register_path(
              email: params[:email],
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            ),
            params
          )
          render searls_auth_config.login_view, layout: searls_auth_config.layout, status: :unprocessable_entity
        end
      end

      def destroy
        ResetsSession.new.reset(self, except_for: [:has_logged_in_before])

        flash[:notice] = searls_auth_config.resolve(
          :flash_notice_after_logout,
          params
        )
        redirect_to searls_auth.login_path
      end
    end
  end
end
