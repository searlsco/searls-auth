require "securerandom"

module Searls
  module Auth
    class BaseController < ApplicationController # TODO should this be ActionController::Base? Trade-offs?
      helper Rails.application.helpers
      helper Rails.application.routes.url_helpers

      protected

      def attach_email_otp_to_session!(user)
        session[:searls_auth_email_otp_user_id] = user.id
        session[:searls_auth_email_otp] = SecureRandom.random_number(1000000).to_s.rjust(6, "0")
        session[:searls_auth_email_otp_generated_at] = Time.current
        session[:searls_auth_email_otp_verification_attempts] = 0
      end

      def reset_expired_email_otp
        if (generated_at = session[:searls_auth_email_otp_generated_at]).present? &&
            Time.zone.parse(generated_at) < Searls::Auth.config.email_otp_expiry_minutes.minutes.ago
          clear_email_otp_from_session!
        end
      end

      def clear_email_otp_from_session!
        session.delete(:searls_auth_email_otp_user_id)
        session.delete(:searls_auth_email_otp_generated_at)
        session.delete(:searls_auth_email_otp)
        session.delete(:searls_auth_email_otp_verification_attempts)
      end

      def log_email_otp_verification_attempt!
        session[:searls_auth_email_otp_verification_attempts] ||= 0
        session[:searls_auth_email_otp_verification_attempts] += 1
      end

      def target_redirect_url
        Searls::Auth::BuildsTargetRedirectUrl.new.build(request, params)
      end

      def redirect_with_host_awareness(target)
        options = {}
        options[:allow_other_host] = true if target&.start_with?("http://", "https://")
        redirect_to target, **options
      end

      def redirect_after_login(user)
        if (target = target_redirect_url)
          redirect_with_host_awareness(target)
        else
          redirect_to Searls::Auth.config.resolve(
            :redirect_path_after_login,
            user, params, request, main_app
          ) || searls_auth.login_path
        end
      end

      private
    end
  end
end
