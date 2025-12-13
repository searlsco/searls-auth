module Searls
  module Auth
    class RequestsPasswordResetsController < BaseController
      before_action :ensure_password_reset_enabled
      before_action :clear_email_otp_from_session!, only: [:show, :create]

      def show
        render Searls::Auth.config.password_reset_request_view, layout: Searls::Auth.config.layout
      end

      def create
        email = params[:email].to_s.strip
        user = Searls::Auth.config.user_finder_by_email.call(email)

        if proceed_with_password_reset_request?(user)
          Searls::Auth::DeliversPasswordReset.new.deliver(
            user:,
            redirect_path: params[:redirect_path],
            redirect_host: params[:redirect_host]
          )
        end

        flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_password_reset_email, params)
        redirect_to searls_auth.password_reset_request_path(
          email: email,
          redirect_path: params[:redirect_path],
          redirect_host: params[:redirect_host]
        )
      end

      private

      def ensure_password_reset_enabled
        return if Searls::Auth.config.password_reset_enabled?

        flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_password_reset_not_enabled, params)
        redirect_to searls_auth.login_path(
          redirect_path: params[:redirect_path],
          redirect_host: params[:redirect_host]
        )
        nil
      end

      def proceed_with_password_reset_request?(user)
        return false if user.blank?

        result = Searls::Auth.config.before_password_reset.call(user, params, self)
        !(result == false || result == :halt)
      end
    end
  end
end
