require "securerandom"

module Searls
  module Auth
    class BaseController < ApplicationController
      helper Rails.application.helpers
      helper Rails.application.routes.url_helpers
      helper_method :forwardable_params

      def forwardable_params
        {redirect_path: params[:redirect_path], redirect_subdomain: params[:redirect_subdomain]}.compact_blank
      end

      protected

      def attach_email_otp_to_session!(user)
        session[:searls_auth_email_otp_user_id] = user.id
        session[:searls_auth_email_otp] = SecureRandom.random_number(1000000).to_s.rjust(6, "0")
        session[:searls_auth_email_otp_generated_at] = Time.current
        session[:searls_auth_email_otp_verification_attempts] = 0
      end

      def reset_expired_email_otp
        generated_at = session[:searls_auth_email_otp_generated_at]
        cutoff = Searls::Auth.config.email_otp_expiry_minutes.minutes.ago
        unless generated_at.present? && (parsed = Searls::Auth::ParsesTimeSafely.new.parse(generated_at)) && parsed > cutoff
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
        redirect_to target, allow_other_host: target&.start_with?("http://", "https://")
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
    end
  end
end
