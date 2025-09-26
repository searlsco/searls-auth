module Searls
  module Auth
    class VerificationsController < BaseController
      before_action :reset_expired_email_otp

      def show
        if !(Searls::Auth.config.auth_methods & [:email_link, :email_otp]).any?
          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        else
          render Searls::Auth.config.verify_view, layout: Searls::Auth.config.layout
        end
      end

      def create
        auth_method = params[:short_code].present? ? :email_otp : :email_link
        if auth_method == :email_otp && !Searls::Auth.config.auth_methods.include?(:email_otp)
          flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_verify_attempt_invalid_link, params)
          return redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
        if auth_method == :email_link && !Searls::Auth.config.auth_methods.include?(:email_link)
          flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_verify_attempt_invalid_link, params)
          return redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
        authenticator = AuthenticatesUser.new
        result = case auth_method
        when :email_otp
          log_email_otp_verification_attempt!
          authenticator.authenticate_by_email_otp(params[:short_code], session)
        when :email_link
          authenticator.authenticate_by_token(params[:token])
        end

        if result.success?
          if [:email_otp, :email_link].include?(auth_method)
            unless Searls::Auth.config.email_verified_predicate.call(result.user)
              Searls::Auth.config.email_verified_setter.call(result.user)
            end
          end
          session[:user_id] = result.user.id
          session[:has_logged_in_before] = true
          flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_login, result.user, params)
          if (target = target_redirect_url)
            redirect_with_host_awareness(target)
          else
            redirect_to Searls::Auth.config.resolve(:redirect_path_after_login, result.user, params, request, main_app)
          end
        elsif auth_method == :email_otp
          if result.exceeded_email_otp_attempt_limit?
            clear_email_otp_from_session!
            flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_verify_attempt_exceeds_limit, params)
            redirect_to searls_auth.login_path(
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            )
          else
            flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_verify_attempt_incorrect_email_otp, params)
            render Searls::Auth.config.verify_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
          end
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
