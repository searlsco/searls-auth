module Searls
  module Auth
    class LoginsController < BaseController
      before_action :reset_expired_email_otp

      def show
        render Searls::Auth.config.login_view, layout: Searls::Auth.config.layout
      end

      def create
        if Searls::Auth.config.auth_methods.include?(:password) && params[:send_login_email].blank?
          handle_password_login
        else
          handle_email_login
        end
      end

      def destroy
        ResetsSession.new.reset(self, except_for: [:has_logged_in_before])

        flash[:notice] = Searls::Auth.config.resolve(
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

          flash[:notice] = if email_verification_enabled? && !Searls::Auth.config.email_verified_predicate.call(result.user)
            resend_path = searls_auth.resend_email_verification_path(
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            )
            Searls::Auth.config.resolve(
              :flash_notice_after_login_with_unverified_email,
              resend_path,
              params
            )
          else
            Searls::Auth.config.resolve(
              :flash_notice_after_login,
              result.user, params
            )
          end
          redirect_after_login(result.user)
        elsif result.email_unverified?
          session[:searls_auth_pending_email] = params[:email]
          resend_path = searls_auth.resend_email_verification_path(redirect_path: params[:redirect_path], redirect_subdomain: params[:redirect_subdomain])
          flash.now[:alert] = Searls::Auth.config.resolve(:flash_error_after_login_attempt_unverified_email, resend_path, params)
          render Searls::Auth.config.login_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
        else
          user = Searls::Auth.config.user_finder_by_email.call(params[:email])
          flash.now[:alert] = if user.blank?
            Searls::Auth.config.resolve(
              :flash_error_after_login_attempt_unknown_email,
              searls_auth.register_path(
                email: params[:email],
                redirect_path: params[:redirect_path],
                redirect_subdomain: params[:redirect_subdomain]
              ),
              params
            )
          else
            Searls::Auth.config.resolve(:flash_error_after_login_attempt_invalid_password, params)
          end
          render Searls::Auth.config.login_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
        end
      rescue NameError
        flash.now[:alert] = Searls::Auth.config.resolve(:flash_error_after_password_misconfigured, params)
        render Searls::Auth.config.login_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
      end

      def handle_email_login
        user = Searls::Auth.config.user_finder_by_email.call(params[:email])

        if user.present?
          if Searls::Auth.config.auth_methods.include?(:email_otp)
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
          flash[:notice] = Searls::Auth.config.resolve(
            :flash_notice_after_login_attempt,
            user, params
          )
          redirect_to searls_auth.verify_path({
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          }.compact_blank)
        else
          flash.now[:alert] = Searls::Auth.config.resolve(
            :flash_error_after_login_attempt_unknown_email,
            searls_auth.register_path(
              email: params[:email],
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            ),
            params
          )
          render Searls::Auth.config.login_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
        end
      end

      def email_verification_enabled?
        Searls::Auth.config.email_verification_mode != :none
      end
    end
  end
end
