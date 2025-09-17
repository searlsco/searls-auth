class Searls::ConfigValidationTest < TLDR
  def setup
    @prev_methods = Searls::Auth.config.auth_methods
    @prev_mode = Searls::Auth.config.email_verification_mode
  end

  def teardown
    Searls::Auth.configure do |c|
      c.auth_methods = @prev_methods
      c.email_verification_mode = @prev_mode
    end
  end

  def test_requires_email_method_when_verification_enabled
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :required
    end
    assert_raises(Searls::Auth::Error) { Searls::Auth::CONFIG.validate! }
  end
end
