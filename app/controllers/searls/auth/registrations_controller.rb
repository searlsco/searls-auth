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
          flash.now[:error] = searls_auth_config.resolve(
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

        if password_registration
          case searls_auth_config.email_verification_mode
          when :required
            if email_methods_enabled
              attach_short_code_to_session!(user)
              EmailsLink.new.email(
                user: user,
                short_code: session[:searls_auth_short_code],
                redirect_path: params[:redirect_path],
                redirect_subdomain: params[:redirect_subdomain]
              )
            end
            flash[:notice] = searls_auth_config.resolve(:flash_notice_after_registration, user, params)
            redirect_to searls_auth.verify_path(
              redirect_path: params[:redirect_path],
              redirect_subdomain: params[:redirect_subdomain]
            )
          when :optional
            if email_methods_enabled
              attach_short_code_to_session!(user)
              EmailsLink.new.email(
                user: user,
                short_code: session[:searls_auth_short_code],
                redirect_path: params[:redirect_path],
                redirect_subdomain: params[:redirect_subdomain]
              )
            end
            complete_login_and_redirect(user)
          else # :none
            complete_login_and_redirect(user)
          end
        elsif email_methods_enabled
          attach_short_code_to_session!(user)
          EmailsLink.new.email(
            user: user,
            short_code: session[:searls_auth_short_code],
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
          flash[:notice] = searls_auth_config.resolve(:flash_notice_after_registration, user, params)
          redirect_to searls_auth.verify_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        else
          complete_login_and_redirect(user)
        end
      end

      def complete_login_and_redirect(user)
        session[:user_id] = user.id
        session[:has_logged_in_before] = true
        flash[:notice] = searls_auth_config.resolve(:flash_notice_after_verification, user, params)
        if params[:redirect_subdomain].present? && params[:redirect_subdomain] != request.subdomain
          redirect_to generate_full_url(
            params[:redirect_path],
            params[:redirect_subdomain]
          ), allow_other_host: true
        elsif params[:redirect_path].present?
          redirect_to params[:redirect_path]
        else
          redirect_to searls_auth_config.resolve(:default_redirect_path_after_login, user, params, request, main_app)
        end
      end
    end
  end
end
