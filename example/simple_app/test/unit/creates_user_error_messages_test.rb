require "test_helper"

class CreatesUserErrorMessagesTest < ActiveSupport::TestCase
  setup do
    current = Searls::Auth.config
    @previous_config = {
      user_finder_by_email: current.user_finder_by_email,
      user_finder_by_email_for_registration: current.user_finder_by_email_for_registration,
      existing_user_registration_blocked_predicate: current.existing_user_registration_blocked_predicate,
      validate_registration: current.validate_registration,
      user_initializer: current.user_initializer
    }

    Searls::Auth.configure do |config|
      config.user_finder_by_email = ->(_email) {}
      config.user_finder_by_email_for_registration = ->(_email) {}
      config.existing_user_registration_blocked_predicate = ->(_user, _params) { false }
      config.validate_registration = ->(_user, _params, errors) { errors }
      config.user_initializer = ->(params) { FakeUser.new(email: params[:email]) }
    end
  end

  teardown do
    Searls::Auth.configure do |config|
      config.user_finder_by_email = @previous_config[:user_finder_by_email]
      config.user_finder_by_email_for_registration = @previous_config[:user_finder_by_email_for_registration]
      config.existing_user_registration_blocked_predicate = @previous_config[:existing_user_registration_blocked_predicate]
      config.validate_registration = @previous_config[:validate_registration]
      config.user_initializer = @previous_config[:user_initializer]
    end
  end

  def test_failed_save_returns_array_of_error_messages
    result = Searls::Auth::CreatesUser.new.call(ActionController::Parameters.new(email: "fake@example.com"))

    refute result.success?
    assert_equal ["Email is invalid", "Password is too short"], result.error_messages
  end

  class FakeUser
    include ActiveModel::Model
    include ActiveModel::Validations

    attr_accessor :email

    validate do
      errors.add(:email, "is invalid")
      errors.add(:password, "is too short")
    end

    def persisted?
      false
    end

    def save
      valid?
      false
    end
  end
end
