module Searls
  module Auth
    class HelperMethods
      def initialize(view_context)
        @view_context = view_context
      end

      def routes
        Searls::Auth::Engine.routes.url_helpers
      end

      def login_path(**kwargs)
        routes.login_path(forwardable_params.merge(kwargs))
      end

      def login_url(**kwargs)
        routes.login_url(forwardable_params.merge(kwargs))
      end

      def register_path(**kwargs)
        routes.register_path(forwardable_params.merge(kwargs))
      end

      def register_url(**kwargs)
        routes.register_url(forwardable_params.merge(kwargs))
      end

      def password_reset_request_path(**kwargs)
        routes.password_reset_request_path(forwardable_params.merge(kwargs))
      end

      def password_reset_available?
        Searls::Auth.config.password_reset_enabled?
      end

      def login_stimulus_controller
        "searls-auth-login"
      end

      def email_field_stimulus_data
        {
          action: "change->searls-auth-login#updateEmail"
        }
      end

      def otp_stimulus_controller
        "searls-auth-otp"
      end

      def otp_field_stimulus_data
        {
          action: "paste->searls-auth-otp#pasted input->otp#caret click->searls-auth-otp#caret keydown->searls-auth-otp#caret keyup->searls-auth-otp#caret",
          searls_auth_otp_target: "input"
        }
      end

      def enable_turbo?
        params[:redirect_subdomain].blank? || params[:redirect_subdomain] == request.subdomain
      end

      def attr_for(model, field_name)
        if model.respond_to?(field_name)
          model.send(field_name)
        end
      end

      def rpad(s, spacer = " ", times = 1)
        return "" if s.blank?
        "#{s}#{spacer * times}"
      end

      private

      def forwardable_params
        @view_context.forwardable_params
      end

      def params
        @view_context.params
      end
    end

    module ApplicationHelper
      def searls_auth_helper
        @__searls_auth_helper ||= HelperMethods.new(self)
      end
    end
  end
end
