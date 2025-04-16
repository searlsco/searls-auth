module Searls
  module Auth
    class LoginsController < BaseController
      before_action :reset_expired_short_code

      def show
        render searls_auth_config.login_view, layout: searls_auth_config.layout
      end

      def create
        user = searls_auth_config.user_finder_by_email.call(params[:email])

        if user.present?
          attach_short_code_to_session!(user)
          EmailsLink.new.email(
            user:,
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain],
            short_code: session[:email_auth_short_code]
          )
          flash[:notice] = "Login details sent to #{params[:email]}"
          redirect_to searls_auth.verify_path(
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )
        else
          flash.now[:error] = "We don't know that email. <a href=\"#{searls_auth.register_path(
            email: params[:email],
            redirect_path: params[:redirect_path],
            redirect_subdomain: params[:redirect_subdomain]
          )}\">Sign up</a> instead?".html_safe
          render searls_auth_config.login_view, layout: searls_auth_config.layout, status: :unprocessable_entity
        end
      end

      def destroy
        ResetsSession.new.reset(self, except_for: [:has_logged_in_before])

        flash[:notice] = "You've been logged out."
        redirect_to searls_auth.login_path
      end
    end
  end
end
