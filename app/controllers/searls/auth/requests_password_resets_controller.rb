module Searls
  module Auth
    class RequestsPasswordResetsController < BaseController
      before_action :ensure_password_reset_enabled
      before_action :clear_email_otp_from_session!, only: [:show, :create]

      def show
        render searls_auth_config.password_reset_request_view, layout: searls_auth_config.layout
      end

      def create
        email = params[:email].to_s.strip
        user = searls_auth_config.user_finder_by_email.call(email)

        if proceed_with_password_reset_request?(user) && deliverable_user?(user)
          Searls::Auth::DeliversPasswordReset.new.deliver(
            user:,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        end

        flash[:notice] = searls_auth_config.resolve(:flash_notice_after_password_reset_email, params)
        redirect_to searls_auth.password_reset_request_path(
          email: email,
          redirect_path: params[:redirect_path],
          redirect_subdomain: params[:redirect_subdomain]
        )
      end

      private

      def ensure_password_reset_enabled
        return if searls_auth_config.password_reset_enabled?

        flash[:error] = searls_auth_config.resolve(:flash_error_after_password_reset_not_enabled, params)
        redirect_to searls_auth.login_path(
          redirect_path: params[:redirect_path],
          redirect_subdomain: params[:redirect_subdomain]
        ) and return
      end

      def deliverable_user?(user)
        return false if user.blank?
        return true unless user.respond_to?(:password_digest)

        user.password_digest.present?
      end

      def proceed_with_password_reset_request?(user)
        hook = searls_auth_config.before_password_reset
        return true unless hook.respond_to?(:call)

        result = hook.call(user, params, self)
        !(result == false || result == :halt)
      end
    end
  end
end
