require_relative "engine"

module Searls
  module Auth
    class CreatesUser
      include Engine.routes.url_helpers
      Result = Struct.new(:user, :success?, :error_messages)

      def call(params)
        user = Searls::Auth.config.user_finder_by_email.call(params[:email]) ||
          Searls::Auth.config.user_initializer.call(params)

        if user.persisted?
          Result.new(nil, false, ["An account already exists for that email address. <a href=\"#{login_path(**forwardable_params(params))}\">Log in</a> instead?".html_safe])
        elsif (errors = Searls::Auth.config.validate_registration.call(user, params, [])).any?
          Result.new(nil, false, errors)
        else
          if params[:password].present?
            Searls::Auth.config.password_setter.call(user, params[:password])
            if params[:password_confirmation].present? && user.respond_to?(:password_confirmation=)
              user.password_confirmation = params[:password_confirmation]
            end
          end
          if user.save
            Result.new(user, true)
          else
            Result.new(user, false, simplified_error_messages(user))
          end
        end
      end

      private

      def forwardable_params(params)
        params.permit(:redirect_path, :redirect_subdomain, :email)
      end

      def simplified_error_messages(model)
        model.errors.details.keys.map { |attr|
          model.errors.full_messages_for(attr).first
        }.join
      end
    end
  end
end
