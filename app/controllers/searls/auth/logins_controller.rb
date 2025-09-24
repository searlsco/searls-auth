module Searls
  module Auth
    class LoginsController < BaseController
      before_action :reset_expired_email_otp

      def show
        render searls_auth_config.login_view, layout: searls_auth_config.layout
      end

      def create
        if searls_auth_config.auth_methods.include?(:password) && params[:send_login_email].blank?
          handle_password_login
        else
          handle_email_login
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

      private

      def handle_password_login
        authenticator = AuthenticatesUser.new
        result = authenticator.authenticate_by_password(params[:email], params[:password], session)

        if result.success?
          session[:user_id] = result.user.id
          session[:has_logged_in_before] = true
          flash[:notice] = searls_auth_config.resolve(
            :flash_notice_after_verification,
            result.user, params
          )
          redirect_after_login(result.user)
        elsif result.email_unverified?
          resend_path = searls_auth.resend_verification_path(email: params[:email], redirect_path: params[:redirect_path], redirect_subdomain: params[:redirect_subdomain])
          flash.now[:alert] = searls_auth_config.resolve(:flash_error_after_login_attempt_unverified_email, resend_path, params)
          render searls_auth_config.login_view, layout: searls_auth_config.layout, status: :unprocessable_entity
        else
          user = searls_auth_config.user_finder_by_email.call(params[:email])
          flash.now[:alert] = if user.blank?
            searls_auth_config.resolve(
              :flash_error_after_login_attempt_unknown_email,
              searls_auth.register_path(
                email: params[:email],
                redirect_path: params[:redirect_path],
                redirect_subdomain: params[:redirect_subdomain]
              ),
              params
            )
          else
            searls_auth_config.resolve(:flash_error_after_login_attempt_invalid_password, params)
          end
          render searls_auth_config.login_view, layout: searls_auth_config.layout, status: :unprocessable_entity
        end
      rescue NameError
        flash.now[:alert] = searls_auth_config.resolve(:flash_error_after_password_misconfigured, params)
        render searls_auth_config.login_view, layout: searls_auth_config.layout, status: :unprocessable_entity
      end

      def handle_email_login
        user = searls_auth_config.user_finder_by_email.call(params[:email])

        if user.present?
          if searls_auth_config.auth_methods.include?(:email_otp)
            attach_email_otp_to_session!(user)
          else
            clear_email_otp_from_session!
          end

          EmailsLink.new.email(
            user:,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain],
            email_otp: session[:searls_auth_email_otp]
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
          flash.now[:alert] = searls_auth_config.resolve(
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
    end
  end
end
