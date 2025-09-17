module Searls
  module Auth
    class ResetsPassword
      Result = Struct.new(:success?, :errors, :user, keyword_init: true)

      def reset(user:, password:, password_confirmation:)
        configuration = Searls::Auth.config

        if password.blank?
          message = configuration.resolve(:flash_error_after_password_reset_password_blank, {})
          return Result.new(success?: false, errors: Array(message), user: user)
        end

        if password != password_confirmation
          message = configuration.resolve(:flash_error_after_password_reset_password_mismatch, {})
          return Result.new(success?: false, errors: Array(message), user: user)
        end

        configuration.password_setter.call(user, password)
        if user.respond_to?(:password_confirmation=)
          user.password_confirmation = password_confirmation
        end

        if user.save
          configuration.password_reset_token_clearer.call(user)
          configuration.after_login_success&.call(user)
          Result.new(success?: true, user: user, errors: [])
        else
          Result.new(success?: false, user: user, errors: simplified_error_messages(user))
        end
      end

      private

      def simplified_error_messages(model)
        model.errors.details.keys.map { |attr|
          model.errors.full_messages_for(attr).first
        }.compact
      end
    end
  end
end
