require "securerandom"
require "uri"

module Searls
  module Auth
    class BaseController < ApplicationController # TODO should this be ActionController::Base? Trade-offs?
      helper Rails.application.helpers
      helper Rails.application.routes.url_helpers

      protected

      def searls_auth_config
        Searls::Auth.config
      end

      def attach_short_code_to_session!(user)
        session[:searls_auth_short_code_user_id] = user.id
        session[:searls_auth_short_code] = SecureRandom.random_number(1000000).to_s.rjust(6, "0")
        session[:searls_auth_short_code_generated_at] = Time.current
        session[:searls_auth_short_code_verification_attempts] = 0
      end

      def reset_expired_short_code
        if session[:searls_auth_short_code_generated_at].present? &&
            Time.zone.parse(session[:searls_auth_short_code_generated_at]) < Searls::Auth.config.token_expiry_minutes.minutes.ago
          clear_short_code_from_session!
        end
      end

      def clear_short_code_from_session!
        session.delete(:searls_auth_short_code_user_id)
        session.delete(:searls_auth_short_code_generated_at)
        session.delete(:searls_auth_short_code)
        session.delete(:searls_auth_short_code_verification_attempts)
      end

      def log_short_code_verification_attempt!
        session[:searls_auth_short_code_verification_attempts] ||= 0
        session[:searls_auth_short_code_verification_attempts] += 1
      end

      def generate_full_url(path, subdomain)
        return path if path&.start_with?("http://", "https://")

        uri = URI.parse(request.base_url)
        host_parts = uri.host.split(".")
        if request.subdomain.present?
          host_parts[0] = subdomain
        else
          host_parts.unshift(subdomain)
        end
        uri.host = host_parts.join(".")

        target = path.presence || "/"
        path_and_query, fragment = target.split("#", 2)
        path_segment, query = path_and_query.split("?", 2)

        uri.path = path_segment.start_with?("/") ? path_segment : "/#{path_segment}"
        uri.query = query
        uri.fragment = fragment

        uri.to_s
      end
    end
  end
end
