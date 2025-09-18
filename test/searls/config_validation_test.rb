class Searls::ConfigValidationTest < TLDR
  def setup
    current = Searls::Auth.config
    @previous_config = {
      auth_methods: current.auth_methods,
      email_verification_mode: current.email_verification_mode,
      password_verifier: current.password_verifier,
      password_setter: current.password_setter,
      before_password_reset: current.before_password_reset,
      password_reset_token_generator: current.password_reset_token_generator,
      password_reset_token_finder: current.password_reset_token_finder,
      password_reset_token_clearer: current.password_reset_token_clearer,
      auto_login_after_password_reset: current.auto_login_after_password_reset
    }
    @original_user_constant = Object.const_get(:User) if Object.const_defined?(:User)
  end

  def teardown
    Searls::Auth.configure do |c|
      c.auth_methods = @previous_config[:auth_methods]
      c.email_verification_mode = @previous_config[:email_verification_mode]
      c.password_verifier = @previous_config[:password_verifier]
      c.password_setter = @previous_config[:password_setter]
      c.before_password_reset = @previous_config[:before_password_reset]
      c.password_reset_token_generator = @previous_config[:password_reset_token_generator]
      c.password_reset_token_finder = @previous_config[:password_reset_token_finder]
      c.password_reset_token_clearer = @previous_config[:password_reset_token_clearer]
      c.auto_login_after_password_reset = @previous_config[:auto_login_after_password_reset]
    end
    restore_user_constant
  end

  def test_requires_callable_password_reset_hooks
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.password_reset_token_generator = nil
    end

    assert_raises(Searls::Auth::Error) { Searls::Auth::CONFIG.validate! }
  end

  def test_before_password_reset_must_be_callable_when_provided
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.before_password_reset = :nope
    end

    assert_raises(Searls::Auth::Error) { Searls::Auth::CONFIG.validate! }
  end

  def test_requires_email_method_when_verification_enabled
    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :required
    end
    assert_raises(Searls::Auth::Error) { Searls::Auth::CONFIG.validate! }
  end

  def test_nil_email_verification_mode_defaults_to_none
    Searls::Auth.configure do |c|
      c.auth_methods = [:email_link]
      c.email_verification_mode = nil
    end

    Searls::Auth::CONFIG.validate!
    assert_equal :none, Searls::Auth::CONFIG[:email_verification_mode]
  end

  def test_password_defaults_require_authenticate_and_digest
    install_user_stub(Class.new)

    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.password_verifier = Searls::Auth::DEFAULT_CONFIG[:password_verifier]
      c.password_setter = Searls::Auth::DEFAULT_CONFIG[:password_setter]
    end

    error = assert_raises(Searls::Auth::Error) { Searls::Auth::CONFIG.validate! }
    assert_includes error.message, "User#authenticate"
    assert_includes error.message, "users.password_digest"
  end

  def test_custom_password_hooks_skip_default_requirements
    install_user_stub(Class.new do
      def initialize
        @secret = nil
      end

      def legacy_secret
        @secret
      end

      def legacy_secret=(value)
        @secret = value
      end
    end)

    Searls::Auth.configure do |c|
      c.auth_methods = [:password]
      c.password_verifier = ->(user, password) { user.legacy_secret == password }
      c.password_setter = ->(user, password) { user.legacy_secret = password }
    end

    Searls::Auth::CONFIG.validate!
  end

  private

  def install_user_stub(klass)
    remove_user_constant
    Object.const_set(:User, klass)
  end

  def restore_user_constant
    current_original = @original_user_constant
    remove_user_constant
    Object.const_set(:User, current_original) if current_original
  end

  def remove_user_constant
    Object.send(:remove_const, :User) if Object.const_defined?(:User)
  end
end
