require "securerandom"
require "uri"

module Searls
  module Auth
    class BaseController < ApplicationController # TODO should this be ActionController::Base? Trade-offs?
      helper Rails.application.helpers
      helper Rails.application.routes.url_helpers
      before_action :sanitize_redirect_parameters

      protected

      def searls_auth_config
        Searls::Auth.config
      end

      def attach_email_otp_to_session!(user)
        session[:searls_auth_email_otp_user_id] = user.id
        session[:searls_auth_email_otp] = SecureRandom.random_number(1000000).to_s.rjust(6, "0")
        session[:searls_auth_email_otp_generated_at] = Time.current
        session[:searls_auth_email_otp_verification_attempts] = 0
      end

      def reset_expired_email_otp
        generated_at = session[:searls_auth_email_otp_generated_at]
        if generated_at.present?
          parsed = otp_generated_at(generated_at)
          if parsed && parsed < otp_expiry_cutoff
            clear_email_otp_from_session!
          end
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

      def otp_expiry_cutoff
        minutes = searls_auth_config.email_otp_expiry_minutes.to_i
        Time.zone.now - (minutes * 60)
      end

      def otp_generated_at(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def full_redirect_target
        Searls::Auth::GeneratesFullUrl.new(
          request,
          drop_subdomain: drop_subdomain?,
          path_supplied: redirect_path_supplied?
        ).generate(path: params[:redirect_path], subdomain: params[:redirect_subdomain])
      end

      def redirect_with_host_awareness(target)
        options = {}
        options[:allow_other_host] = true if target&.start_with?("http://", "https://")
        redirect_to target, **options
      end

      def redirect_after_login(user)
        if redirect_path_supplied? && (target = full_redirect_target)
          redirect_with_host_awareness(target)
        else
          redirect_to searls_auth_config.resolve(
            :redirect_path_after_login,
            user, params, request, main_app
          ) || searls_auth.login_path
        end
      end

      private

      def sanitize_redirect_parameters
        raw_subdomain = params[:redirect_subdomain]
        @redirect_drop_to_root = drop_subdomain_requested?(raw_subdomain)
        @redirect_path_supplied = param_supplied?(:redirect_path)
        params[:redirect_subdomain] = sanitized_subdomain(raw_subdomain)
        params[:redirect_path] = sanitized_path(params[:redirect_path])
      end

      def sanitized_subdomain(raw)
        return if raw.blank?

        value = raw.to_s.downcase
        value if value.match?(/\A[a-z0-9-]+\z/)
      end

      def sanitized_path(raw)
        return if raw.blank?

        value = raw.to_s.strip
        return if value.blank?

        uri = parse_uri(value)
        value = path_from_uri(uri) if uri && (uri.host.present? || uri.scheme.present?)

        normalized = value.start_with?("/") ? value : "/#{value}"
        return if normalized.start_with?("//")

        normalized
      end

      def parse_uri(value)
        URI.parse(value)
      rescue URI::InvalidURIError
        nil
      end

      def path_from_uri(uri)
        path = uri.path.presence || "/"
        path += "?#{uri.query}" if uri.query.present?
        path += "##{uri.fragment}" if uri.fragment.present?
        path
      end

      def redirect_path_supplied?
        !!@redirect_path_supplied
      end

      def param_supplied?(key)
        params.key?(key) || params.key?(key.to_s)
      end

      def drop_subdomain?
        !!@redirect_drop_to_root
      end

      def drop_subdomain_requested?(raw)
        return false unless raw.is_a?(String)

        raw.strip.empty?
      end
    end
  end
end
