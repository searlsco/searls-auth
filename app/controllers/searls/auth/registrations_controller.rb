module Searls
  module Auth
    class RegistrationsController < BaseController
      def show
        render Searls::Auth.config.register_view, layout: Searls::Auth.config.layout
      end

      def create
        result = CreatesUser.new.call(params)

        if result.success?
          user = result.user
          if password_registration?
            handle_password_registration(user)
          else
            handle_email_registration(user)
          end
        else
          flash.now[:alert] = Searls::Auth.config.resolve(:flash_error_after_register_attempt, result.error_messages, searls_auth.login_path(email: params[:email], **forwardable_params), params)
          render Searls::Auth.config.register_view, layout: Searls::Auth.config.layout, status: :unprocessable_content
        end
      end

      def pending_email_verification
        render Searls::Auth.config.pending_email_verification_view, layout: Searls::Auth.config.layout
      end

      private

      def password_registration?
        Searls::Auth.config.auth_methods.include?(:password) && params[:password].present?
      end

      def email_methods_enabled?
        (Searls::Auth.config.auth_methods & [:email_link, :email_otp]).any?
      end

      def handle_password_registration(user)
        target_path, target_subdomain = registration_redirect_destination(user)
        if Searls::Auth.config.email_verification_mode != :none
          EmailsVerification.new.email(user: user, redirect_path: target_path, redirect_subdomain: target_subdomain)
          session[:searls_auth_pending_email] = user.email
          session[:searls_auth_pending_redirect_path] = target_path
          session[:searls_auth_pending_redirect_subdomain] = target_subdomain
        end

        if Searls::Auth.config.email_verification_mode == :required
          flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_registration, user, params)
          redirect_to searls_auth.pending_email_verification_path({email: user.email, redirect_path: target_path, redirect_subdomain: target_subdomain}.compact_blank)
        else
          session[:user_id] = user.id
          session[:has_logged_in_before] = true
          flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_login, user, params)
          if (target = target_redirect_url)
            redirect_with_host_awareness(target)
          else
            fallback = Searls::Auth.config.resolve(:redirect_path_after_login, user, params, request, main_app)
            redirect_to(fallback || searls_auth.login_path)
          end
        end
      end

      def handle_email_registration(user)
        return unless email_methods_enabled?
        target_path, target_subdomain = registration_redirect_destination(user)
        enqueue_login_verification_email(user, target_path:, target_subdomain:)
        flash[:notice] = Searls::Auth.config.resolve(:flash_notice_after_registration, user, params)
        redirect_to searls_auth.verify_path(**forwardable_params)
      end

      def registration_redirect_destination(user)
        if redirect_params_supplied?
          [params[:redirect_path], params[:redirect_subdomain]]
        else
          [Searls::Auth.config.resolve(:redirect_path_after_register, user, params, request, main_app), nil]
        end
      end

      def redirect_params_supplied?
        params[:redirect_path].present? || params[:redirect_subdomain].present?
      end

      def enqueue_login_verification_email(user, target_path:, target_subdomain:)
        email_otp = nil
        if Searls::Auth.config.auth_methods.include?(:email_otp)
          attach_email_otp_to_session!(user)
          email_otp = session[:searls_auth_email_otp]
        else
          clear_email_otp_from_session!
        end
        EmailsLink.new.email(
          user: user,
          email_otp: email_otp,
          redirect_path: target_path,
          redirect_subdomain: target_subdomain
        )
      end
    end
  end
end
