require "application_system_test_case"

class VerifyRoutesRedirectTest < ApplicationSystemTestCase
  setup do
    @prev_methods = Searls::Auth.config.auth_methods
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
    end
  end

  teardown do
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
    end
  end

  def test_verify_routes_redirect_to_login
    visit searls_auth.verify_path
    assert_current_path searls_auth.login_path
  end
end
