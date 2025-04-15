require "securerandom"

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
        session[:email_auth_short_code_user_id] = user.id
        session[:email_auth_short_code] = SecureRandom.random_number(1000000).to_s.rjust(6, "0")
        session[:email_auth_short_code_generated_at] = Time.current
      end

      def reset_expired_short_code
        if session[:email_auth_short_code_generated_at].present? &&
            Time.zone.parse(session[:email_auth_short_code_generated_at]) < Searls::Auth.config.token_expiry_minutes.minutes.ago
          clear_short_code_from_session!
        end
      end

      def clear_short_code_from_session!
        session.delete(:email_auth_short_code_user_id)
        session.delete(:email_auth_short_code_generated_at)
        session.delete(:email_auth_short_code)
      end
    end
  end
end
