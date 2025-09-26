module Searls
  module Auth
    class UpdatesSettings
      Result = Struct.new(
        :success?,
        :errors,
        :user,
        :password_changed?,
        keyword_init: true
      )

      def initialize(user:, params:)
        @user = user
        @params = params || {}
        @errors = []
        @password_changed = false
      end

      def update
        enforce_current_password_requirement

        handle_password_change if errors.empty?

        return failure_result unless errors.empty?

        if changes_applied?
          if user.save
            Result.new(
              success?: true,
              user: user,
              errors: [],
              password_changed?: @password_changed
            )
          else
            Result.new(
              success?: false,
              user: user,
              errors: simplified_error_messages(user)
            )
          end
        else
          Result.new(success?: true, user: user, errors: [], password_changed?: false)
        end
      end

      private

      attr_reader :user, :params, :errors

      def enforce_current_password_requirement
        return unless password_present?
        return unless password_change_requested?

        if current_password.blank?
          errors << array_wrap(Searls::Auth.config.resolve(:flash_error_after_settings_current_password_missing, {}))
          errors.flatten!
          return
        end

        begin
          verified = Searls::Auth.config.password_verifier.call(user, current_password)
        rescue NameError
          errors << array_wrap(Searls::Auth.config.resolve(:flash_error_after_password_misconfigured, {}))
          errors.flatten!
          return
        end

        unless verified
          errors << array_wrap(Searls::Auth.config.resolve(:flash_error_after_settings_current_password_invalid, {}))
          errors.flatten!
        end
      end

      def handle_password_change
        return unless password_change_requested?

        if new_password.blank?
          errors << array_wrap(Searls::Auth.config.resolve(:flash_error_after_password_reset_password_blank, {}))
          errors.flatten!
          return
        end

        if new_password != new_password_confirmation
          errors << array_wrap(Searls::Auth.config.resolve(:flash_error_after_password_reset_password_mismatch, {}))
          errors.flatten!
          return
        end

        Searls::Auth.config.password_setter.call(user, new_password)
        if user.respond_to?(:password_confirmation=)
          user.password_confirmation = new_password_confirmation
        end
        @password_changed = true
      end

      def password_present?
        Searls::Auth.config.password_present?(user)
      end

      def password_change_requested?
        new_password.present? || new_password_confirmation.present?
      end

      def current_password
        param(:current_password).to_s
      end

      def new_password
        param(:password)
      end

      def new_password_confirmation
        param(:password_confirmation)
      end

      def param(key)
        params[key] || params[key.to_s]
      end

      def changes_applied?
        @password_changed
      end

      def failure_result
        flattened = errors.flatten.compact_blank
        Result.new(success?: false, user: user, errors: flattened.presence || simplified_error_messages(user))
      end

      def array_wrap(value)
        case value
        when Array
          value
        when nil
          []
        else
          [value]
        end
      end

      def simplified_error_messages(model)
        return [] unless model.respond_to?(:errors)

        model.errors.details.keys.map do |attr|
          model.errors.full_messages_for(attr).first
        end.compact
      end
    end
  end
end
