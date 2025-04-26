module Searls
  module Auth
    class VerificationsController < BaseController
      before_action :reset_expired_short_code

      def show
        render searls_auth_config.verify_view, layout: searls_auth_config.layout
      end

      def create
        auth_method = params[:short_code].present? ? :short_code : :token
        authenticator = AuthenticatesUser.new
        result = case auth_method
        when :short_code
          authenticator.authenticate_by_short_code(params[:short_code], session)
        when :token
          authenticator.authenticate_by_token(params[:token])
        end

        if result.success?
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
        elsif auth_method == :short_code
          flash[:error] = searls_auth_config.resolve(
            :flash_error_after_verify_attempt_incorrect_short_code,
            params
          )
          render searls_auth_config.verify_view, layout: searls_auth_config.layout, status: :unprocessable_entity
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

      private

      def generate_full_url(path, subdomain)
        port = request.port
        port_string = (port == 80 || port == 443) ? "" : ":#{port}"

        "#{request.protocol}#{subdomain}.#{request.domain}#{port_string}#{path}"
      end
    end
  end
end
