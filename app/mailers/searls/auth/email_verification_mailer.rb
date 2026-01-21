module Searls
  module Auth
    class EmailVerificationMailer < BaseMailer
      def verification_email
        @config = Searls::Auth.config
        @user = params[:user]
        @token = params[:token]
        @redirect_path = params[:redirect_path]
        @redirect_host = params[:redirect_host]

        mail(
          to: format_to(@user),
          subject: mail_subject,
          template_path: @config.mail_email_verification_template_path,
          template_name: @config.mail_email_verification_template_name
        ) do |format|
          format.html { render layout: @config.mail_layout }
          format.text
        end
      end

      private

      def mail_subject
        "Verify your #{searls_auth_helper.rpad(@config.app_name)}email"
      end
    end
  end
end
