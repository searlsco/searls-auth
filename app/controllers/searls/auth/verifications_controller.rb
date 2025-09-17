module Searls
  module Auth
    class VerificationsController < BaseController
      before_action :reset_expired_short_code

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
          log_short_code_verification_attempt!
          authenticator.authenticate_by_short_code(params[:short_code], session)
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
          if params[:redirect_subdomain].present? && params[:redirect_subdomain] != request.subdomain
            redirect_to generate_full_url(
              params[:redirect_path],
              params[:redirect_subdomain]
            ), allow_other_host: true
          elsif params[:redirect_path].present?
            redirect_to params[:redirect_path]
          else
            redirect_to searls_auth_config.resolve(:default_redirect_path_after_login,
              result.user, params, request, main_app)
          end
        elsif auth_method == :email_otp
          if result.exceeded_short_code_attempt_limit?
            clear_short_code_from_session!
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
              :flash_error_after_verify_attempt_incorrect_short_code,
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
            attach_short_code_to_session!(user)
          else
            clear_short_code_from_session!
          end

          EmailsLink.new.email(
            user: user,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain],
            short_code: session[:searls_auth_short_code]
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

      private

    end
  end
end
