module Searls
  module Auth
    class SettingsController < BaseController
      before_action :ensure_password_auth_enabled
      before_action :ensure_authenticated_user
      before_action :load_settings_user

      helper_method :settings_user, :password_on_file?

      def edit
        render :edit, layout: searls_auth_config.layout
      end

      def update
        permitted_params = settings_params.to_h
        result = UpdatesSettings.new(
          user: settings_user,
          params: permitted_params,
          configuration: searls_auth_config
        ).update

        @settings_user = result.user
        @password_on_file = nil

        if result.success?
          flash[:notice] = searls_auth_config.resolve(:flash_notice_after_settings_update, settings_user, params)
          handle_email_verification_if_needed(result)
        else
          # Normally, we would flash.now and render `settings_view`, but this controller is
          # intended to back forms hosted elsewhere. Redirecting keeps the host UI in control
          # while surfacing validation errors via the session flash.
          flash[:error] = Array(result.errors).compact_blank.first
        end
        redirect_target = searls_auth_config.resolve(
          :redirect_path_after_settings_change,
          settings_user, params, request, searls_auth
        ) || searls_auth.edit_settings_path
        redirect_to redirect_target
      end

      private

      def ensure_password_auth_enabled
        return if searls_auth_config.auth_methods.include?(:password)

        head :not_found and return
      end

      def ensure_authenticated_user
        return if session[:user_id].present?

        redirect_to searls_auth.login_path(
          redirect_path: request.original_fullpath,
          redirect_subdomain: request.subdomain
        ) and return
      end

      def load_settings_user
        @settings_user = searls_auth_config.user_finder_by_id.call(session[:user_id])
        return if @settings_user.present?

        session.delete(:user_id)
        redirect_to searls_auth.login_path(
          redirect_path: request.original_fullpath,
          redirect_subdomain: request.subdomain
        ) and return
      end

      attr_reader :settings_user

      def password_on_file?
        @password_on_file ||= settings_user && searls_auth_config.password_present?(settings_user)
      end

      def settings_params
        permitted = [:password, :password_confirmation, :current_password]
        permitted << :email if password_on_file?

        params.fetch(:settings, ActionController::Parameters.new).permit(permitted)
      end

      def handle_email_verification_if_needed(result)
        return unless result.email_changed?

        email_methods_enabled = (searls_auth_config.auth_methods & [:email_link, :email_otp]).any?
        return unless email_methods_enabled

        email_otp = nil
        if searls_auth_config.auth_methods.include?(:email_otp)
          attach_email_otp_to_session!(settings_user)
          email_otp = session[:searls_auth_email_otp]
        else
          clear_email_otp_from_session!
        end

        EmailsLink.new.email(
          user: settings_user,
          redirect_path: params[:redirect_path],
          redirect_subdomain: params[:redirect_subdomain],
          email_otp: email_otp
        )

        current_notice = Array(flash[:notice]).compact_blank
        current_notice << searls_auth_config.resolve(:flash_notice_after_settings_email_verification_sent, settings_user, params)
        flash[:notice] = current_notice.join(" ")
      end
    end
  end
end
