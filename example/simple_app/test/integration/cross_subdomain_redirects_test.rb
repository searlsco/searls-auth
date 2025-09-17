require "test_helper"

class CrossSubdomainRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_auth_methods = Searls::Auth.config.auth_methods.dup
    @previous_verification_mode = Searls::Auth.config.email_verification_mode
    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.email_verification_mode = :none
    end
  end

  teardown do
    Searls::Auth.configure do |config|
      config.auth_methods = @previous_auth_methods
      config.email_verification_mode = @previous_verification_mode
    end
    User.delete_all
  end

  def test_password_login_redirects_to_requested_subdomain
    user = User.new(email: "cross-subdomain-login@example.com")
    Searls::Auth.config.password_setter.call(user, "sekrit")
    user.save!

    post searls_auth.login_path, params: {
      email: user.email,
      password: "sekrit",
      redirect_path: "/secret",
      redirect_subdomain: "members"
    }

    assert_response :redirect
    assert_equal "http://members.example.com/secret", response.location
  end

  def test_password_registration_redirects_to_requested_subdomain
    post searls_auth.register_path, params: {
      email: "cross-subdomain-register@example.com",
      password: "sekrit",
      password_confirmation: "sekrit",
      redirect_path: "/secret",
      redirect_subdomain: "members"
    }

    assert_response :redirect
    assert_equal "http://members.example.com/secret", response.location
  end
end
