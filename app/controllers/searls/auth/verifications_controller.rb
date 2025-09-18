module Searls
  module Auth
    class VerificationsController < BaseController
      before_action :reset_expired_email_otp

      def show
        if !(searls_auth_config.auth_methods & [:email_link, :email_otp]).any?
          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        else
          render searls_auth_config.verify_view, layout: searls_auth_config.layout
        end
      end

      def create
        auth_method = params[:short_code].present? ? :email_otp : :email_link
        if auth_method == :email_otp && !searls_auth_config.auth_methods.include?(:email_otp)
          flash[:error] = searls_auth_config.resolve(:flash_error_after_verify_attempt_invalid_link, params)
          return redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
        if auth_method == :email_link && !searls_auth_config.auth_methods.include?(:email_link)
          flash[:error] = searls_auth_config.resolve(:flash_error_after_verify_attempt_invalid_link, params)
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
            unless searls_auth_config.email_verified_predicate.call(result.user)
              searls_auth_config.email_verified_setter.call(result.user)
            end
          end
          session[:user_id] = result.user.id
          session[:has_logged_in_before] = true
          flash[:notice] = searls_auth_config.resolve(
            :flash_notice_after_verification,
            result.user, params
          )
          if (target = full_redirect_target)
            redirect_with_host_awareness(target)
          else
            redirect_to searls_auth_config.resolve(:redirect_path_after_login,
              result.user, params, request, main_app)
          end
        elsif auth_method == :email_otp
          if result.exceeded_email_otp_attempt_limit?
            clear_email_otp_from_session!
            flash[:error] = searls_auth_config.resolve(
              :flash_error_after_verify_attempt_exceeds_limit,
              params
            )
            redirect_to searls_auth.login_path(
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            )
          else
            flash[:error] = searls_auth_config.resolve(
              :flash_error_after_verify_attempt_incorrect_email_otp,
              params
            )
            render searls_auth_config.verify_view, layout: searls_auth_config.layout, status: :unprocessable_entity
          end
        else
          flash[:error] = searls_auth_config.resolve(
            :flash_error_after_verify_attempt_invalid_link,
            params
          )
          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
      end

      def resend
        user = searls_auth_config.user_finder_by_email.call(params[:email])
        if user.present? && (searls_auth_config.auth_methods & [:email_link, :email_otp]).any?
          if searls_auth_config.auth_methods.include?(:email_otp)
            attach_email_otp_to_session!(user)
          else
            clear_email_otp_from_session!
          end

          EmailsLink.new.email(
            user: user,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain],
            email_otp: session[:searls_auth_email_otp]
          )
          flash[:notice] = searls_auth_config.resolve(:flash_notice_after_verification_email_resent, params)
          redirect_to searls_auth.verify_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        else
          flash[:error] = searls_auth_config.resolve(:flash_error_after_verify_attempt_invalid_link, params)
          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end
      end
    end
  end
end
