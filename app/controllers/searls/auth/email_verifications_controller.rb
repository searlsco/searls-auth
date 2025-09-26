module Searls
  module Auth
    class EmailVerificationsController < BaseController
      def resend
        user = if session[:user_id].present?
          Searls::Auth.config.user_finder_by_id.call(session[:user_id])
        elsif session[:searls_auth_pending_email].present?
          Searls::Auth.config.user_finder_by_email.call(session[:searls_auth_pending_email])
        end

        if user.blank? || Searls::Auth.config.email_verification_mode == :none
          flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_verify_attempt_invalid_link, params)
        else
          EmailsVerification.new.email(
            user: user,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
          flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_verification_email_resent, params)
        end

        if session[:user_id].present?
          redirect_to searls_auth.verify_path
        else
          fallback = if session[:searls_auth_pending_email].present?
            searls_auth.pending_email_verification_path({
              email: session[:searls_auth_pending_email],
              redirect_path: session[:searls_auth_pending_redirect_path],
              redirect_subdomain: session[:searls_auth_pending_redirect_subdomain]
            }.compact_blank)
          else
            searls_auth.login_path
          end
          redirect_back fallback_location: fallback
        end
      end

      def show
        user = Searls::Auth.config.user_finder_by_token.call(params[:token])

        if user.present?
          unless Searls::Auth.config.email_verified_predicate.call(user)
            Searls::Auth.config.email_verified_setter.call(user)
          end

          flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_email_verified, user, params)

          Searls::Auth.config.after_login_success.call(user)
          session[:user_id] = user.id
          session[:has_logged_in_before] = true

          redirect_after_login(user)
        else
          flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_verify_attempt_invalid_link, params)

          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
      end
    end
  end
end
