module Searls
  module Auth
    class RegistrationsController < BaseController
      def show
        render searls_auth_config.register_view, layout: searls_auth_config.layout
      end

      def create
        result = CreatesUser.new.call(params)

        if result.success?
          handle_post_registration(result.user)
        else
          flash.now[:alert] = searls_auth_config.resolve(
            :flash_error_after_register_attempt,
            result.error_messages,
            searls_auth.login_path(
              email: params[:email],
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            ),
            params
          )
          render searls_auth_config.register_view, layout: searls_auth_config.layout, status: :unprocessable_entity
        end
      end

      private

      def handle_post_registration(user)
        password_registration = searls_auth_config.auth_methods.include?(:password) && params[:password].present?
        email_methods_enabled = (searls_auth_config.auth_methods & [:email_link, :email_otp]).any?

        target_path, target_subdomain = registration_redirect_destination(user)

        if password_registration
          case searls_auth_config.email_verification_mode
          when :required
            enqueue_login_verification_email(user, target_path:, target_subdomain:) if email_methods_enabled
            flash[:notice] = searls_auth_config.resolve(:flash_notice_after_registration, user, params)
            redirect_to searls_auth.verify_path(
              redirect_path: target_path,
              redirect_subdomain: target_subdomain
            )
          when :optional
            enqueue_email_verification_only(user, target_path:, target_subdomain:) if email_methods_enabled
            complete_login_and_redirect(user)
          else # :none
            complete_login_and_redirect(user)
          end
        elsif email_methods_enabled
          enqueue_login_verification_email(user, target_path:, target_subdomain:)
          flash[:notice] = searls_auth_config.resolve(:flash_notice_after_registration, user, params)
          redirect_to searls_auth.verify_path(
            redirect_path: target_path,
            redirect_subdomain: target_subdomain
          )
        else
          complete_login_and_redirect(user)
        end
      end

      def complete_login_and_redirect(user)
        session[:user_id] = user.id
        session[:has_logged_in_before] = true
        flash[:notice] = searls_auth_config.resolve(:flash_notice_after_verification, user, params)
        if redirect_params_supplied?
          if (target = full_redirect_target)
            return redirect_with_host_awareness(target)
          end
        end

        fallback = searls_auth_config.resolve(:redirect_path_after_login, user, params, request, main_app)
        redirect_to(fallback || searls_auth.login_path)
      end

      def registration_redirect_destination(user)
        if redirect_params_supplied?
          [params[:redirect_path], params[:redirect_subdomain]]
        else
          [searls_auth_config.resolve(:redirect_path_after_register, user, params, request, main_app), nil]
        end
      end

      def redirect_params_supplied?
        params[:redirect_path].present? || params[:redirect_subdomain].present?
      end

      def enqueue_login_verification_email(user, target_path:, target_subdomain:)
        email_otp = nil
        if searls_auth_config.auth_methods.include?(:email_otp)
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

      def enqueue_email_verification_only(user, target_path:, target_subdomain:)
        clear_email_otp_from_session!
        EmailsVerification.new.email(
          user: user,
          redirect_path: target_path,
          redirect_subdomain: target_subdomain
        )
      end
    end
  end
end
