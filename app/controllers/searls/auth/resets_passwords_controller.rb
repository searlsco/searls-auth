module Searls
  module Auth
    class ResetsPasswordsController < BaseController
      before_action :ensure_password_reset_enabled
      before_action :load_user_from_token
      before_action :clear_email_otp_from_session!, only: [:show, :update]

      def show
        @token = params[:token]
        @user_email = @user.email
        render Searls::Auth.config.password_reset_edit_view, layout: Searls::Auth.config.layout
      end

      def update
        result = ResetsPassword.new.reset(
          user: @user,
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        if result.success?
          handle_successful_reset(result.user)
        else
          flash.now[:alert] = Array(result.errors).first
          @token = params[:token]
          @user_email = @user.email
          render Searls::Auth.config.password_reset_edit_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
        end
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

      def load_user_from_token
        token = params[:token].to_s
        @user = Searls::Auth.config.password_reset_token_finder.call(token)
        return if @user.present?

        flash[:alert] = Searls::Auth.config.resolve(:flash_error_after_password_reset_token_invalid, params)
        redirect_to searls_auth.password_reset_request_path(
          redirect_path: params[:redirect_path],
          redirect_host: params[:redirect_host]
        )
        nil
      end

      def handle_successful_reset(user)
        flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_password_reset, user, params)

        if Searls::Auth.config.auto_login_after_password_reset
          session[:user_id] = user.id
          session[:has_logged_in_before] = true
          redirect_after_login(user)
        else
          redirect_to searls_auth.login_path(
            redirect_path: params[:redirect_path],
            redirect_host: params[:redirect_host]
          )
        end
      end
    end
  end
end
