require "test_helper"

class CreatesUserRegistrationFinderTest < ActiveSupport::TestCase
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
      config.user_finder_by_email_for_registration = ->(email) { User.find_by(email: email) }
      config.existing_user_registration_blocked_predicate = ->(_user, _params) { false }
      config.validate_registration = ->(_user, _params, errors) { errors }
      config.user_initializer = ->(params) { User.new(email: params[:email]) }
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

    User.delete_all
  end

  def test_registration_uses_user_finder_by_email_for_registration
    existing_user = User.create!(email: "exists@example.com", password: "sekrit")

    result = Searls::Auth::CreatesUser.new.call(
      ActionController::Parameters.new(email: existing_user.email)
    )

    assert result.success?
    assert_equal existing_user.id, result.user.id
  end
end
