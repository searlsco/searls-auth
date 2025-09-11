module Searls
  module Auth
    class LoginLinkMailer < BaseMailer
      def login_link
        @config = Searls::Auth.config
        @user = params[:user]
        @token = params[:token]
        @redirect_path = params[:redirect_path]
        @redirect_subdomain = params[:redirect_subdomain]
        @short_code = params[:short_code]

        mail(
          to: format_to(@user),
          subject: mail_subject,
          template_path: @config.mail_login_template_path,
          template_name: @config.mail_login_template_name
        ) do |format|
          format.html { render layout: @config.mail_layout }
          format.text
        end
      end

      private

      def mail_subject
        methods = Searls::Auth.config.auth_methods
        if methods.include?(:email_otp) && @short_code.present?
          "Your #{searls_auth_helper.rpad(@config.app_name)}login code is #{@short_code}"
        else
          "Your #{searls_auth_helper.rpad(@config.app_name)}login link"
        end
      end
    end
  end
end
