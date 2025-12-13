require "test_helper"

class CrossSubdomainRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_auth_methods = Searls::Auth.config.auth_methods.dup
    @previous_verification_mode = Searls::Auth.config.email_verification_mode
    @previous_token_for_cross_domain_redirect = Searls::Auth.config.token_for_cross_domain_redirect
    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.email_verification_mode = :none
    end
    host! "www.example.com"
  end

  teardown do
    Searls::Auth.configure do |config|
      config.auth_methods = @previous_auth_methods
      config.email_verification_mode = @previous_verification_mode
      config.token_for_cross_domain_redirect = @previous_token_for_cross_domain_redirect
    end
    User.delete_all
  end

  def test_password_login_redirects_to_requested_host
    user = create_user(email: "cross-subdomain-login@example.com")

    post searls_auth.login_path, params: {
      email: user.email,
      password: "sekrit",
      redirect_path: "/secret",
      redirect_host: "members.example.com"
    }

    assert_response :redirect
    assert_equal "http://members.example.com/secret", response.location
  end

  def test_password_registration_redirects_to_requested_host
    post searls_auth.register_path, params: {
      email: "cross-subdomain-register@example.com",
      password: "sekrit",
      password_confirmation: "sekrit",
      redirect_path: "/secret",
      redirect_host: "members.example.com"
    }

    assert_response :redirect
    assert_equal "http://members.example.com/secret", response.location
  end

  def test_password_login_ignores_external_redirect_path
    user = create_user(email: "cross-subdomain-external@example.com")

    post searls_auth.login_path, params: {
      email: user.email,
      password: "sekrit",
      redirect_path: "https://evil.test/phish"
    }

    assert_response :redirect
    assert_equal "http://www.example.com/phish", response.location
  end

  def test_cross_cookie_domain_redirect_host_is_ignored_by_default
    user = create_user(email: "cross-subdomain-invalid@example.com")

    post searls_auth.login_path, params: {
      email: user.email,
      password: "sekrit",
      redirect_path: "/secret",
      redirect_host: "evil.test"
    }

    assert_response :redirect
    assert_equal "http://www.example.com/secret", response.location
  end

  def test_password_login_can_drop_to_root_domain
    host! "auth.example.com"
    user = create_user(email: "cross-subdomain-root@example.com")

    post searls_auth.login_path, params: {
      email: user.email,
      password: "sekrit",
      redirect_path: "/dashboard",
      redirect_host: "example.com"
    }

    assert_response :redirect
    assert_equal "http://example.com/dashboard", response.location
  ensure
    host! "www.example.com"
  end

  def test_password_login_appends_sso_token_when_redirecting_cross_cookie_domain
    user = create_user(email: "cross-cookie-domain@example.com")
    Searls::Auth.configure do |config|
      config.token_for_cross_domain_redirect = ->(user, request, target_host) {
        "token-123" if target_host == "other.test"
      }
    end

    post searls_auth.login_path, params: {
      email: user.email,
      password: "sekrit",
      redirect_path: "/secret",
      redirect_host: "other.test"
    }

    assert_response :redirect
    assert_equal "http://other.test/secret?sso_token=token-123", response.location
  end

  private

  def create_user(email:)
    user = User.new(email:)
    Searls::Auth.config.password_setter.call(user, "sekrit")
    user.save!
    user
  end
end
