class Searls::Auth::ConfigTest < TLDR
  def setup
    current = Searls::Auth.config
    @baseline = {
      auth_methods: current.auth_methods,
      email_verification_mode: current.email_verification_mode,
      password_verifier: current.password_verifier,
      password_setter: current.password_setter,
      before_password_reset: current.before_password_reset,
      password_reset_token_generator: current.password_reset_token_generator,
      password_reset_token_finder: current.password_reset_token_finder,
      auto_login_after_password_reset: current.auto_login_after_password_reset,
      password_present_predicate: current.password_present_predicate,
      password_reset_enabled: current.password_reset_enabled
    }
    @original_user_constant = Object.const_get(:User) if Object.const_defined?(:User)
  end

  def teardown
    restore_user_constant
    Searls::Auth.configure do |c|
      c.auth_methods = @baseline[:auth_methods]
      c.email_verification_mode = @baseline[:email_verification_mode]
      c.password_verifier = @baseline[:password_verifier]
      c.password_setter = @baseline[:password_setter]
      c.before_password_reset = @baseline[:before_password_reset]
      c.password_reset_token_generator = @baseline[:password_reset_token_generator]
      c.password_reset_token_finder = @baseline[:password_reset_token_finder]
      c.auto_login_after_password_reset = @baseline[:auto_login_after_password_reset]
      c.password_present_predicate = @baseline[:password_present_predicate]
      c.password_reset_enabled = @baseline[:password_reset_enabled]
    end
  end

  # auth_methods
  def test_auth_methods_cannot_be_empty
    assert_invalid! { |c| c.auth_methods = [] }
  end

  def test_auth_methods_reject_unknown_values
    assert_invalid! { |c| c.auth_methods = [:password, :sms] }
  end

  def test_auth_methods_are_symbolized
    assert_valid! { |c| c.auth_methods = ["password"] }
    assert_equal [:password], Searls::Auth.config.auth_methods
  end

  # email_verification_mode
  def test_email_verification_mode_defaults_to_none_when_nil
    assert_valid! { |c|
      c.auth_methods = [:email_link]
      c.email_verification_mode = nil
    }
    assert_equal :none, Searls::Auth.config.email_verification_mode
  end

  def test_required_verification_allowed_without_email_methods
    assert_valid! { |c|
      c.auth_methods = [:password]
      c.email_verification_mode = :required
    }
  end

  # password settings
  def test_password_defaults_require_authenticate_and_digest
    install_user_stub(Class.new)
    err = assert_invalid! do |c|
      c.auth_methods = [:password]
      c.password_verifier = Searls::Auth::DEFAULT_CONFIG[:password_verifier]
      c.password_setter = Searls::Auth::DEFAULT_CONFIG[:password_setter]
    end
    assert_includes err.message, "User#authenticate"
  end

  # default User-hook validations
  def test_default_user_hooks_require_user_constant
    remove_user_constant
    cleanup_active_model = ensure_active_model_defined
    snapshot = Searls::Auth.config
    assert_raises(Searls::Auth::Error) do
      Searls::Auth.configure { |c| c.auth_methods = [:email_link] }
    end
    # restore without ActiveModel present so default-user validations are skipped
    cleanup_active_model&.call
    Searls::Auth.configure { |c| snapshot.each_pair { |k, v| c[k] = snapshot[k] } }
  end

  def test_default_user_hooks_require_expected_methods
    # Looks ActiveModel-ish but missing find_by/token helpers
    install_user_stub(Class.new do
      def initialize(*)
      end
      attr_accessor :id
    end)
    cleanup_active_model = ensure_active_model_defined
    snapshot = Searls::Auth.config
    err = assert_raises(Searls::Auth::Error) do
      Searls::Auth.configure { |c| c.auth_methods = [:email_link] }
    end
    assert_includes err.message, "User.find_by"
    cleanup_active_model&.call
    Searls::Auth.configure { |c| snapshot.each_pair { |k, v| c[k] = snapshot[k] } }
  end

  def test_custom_password_hooks_skip_default_requirements
    install_user_stub(Class.new do
      def initialize
        @secret = nil
      end

      def legacy_secret
        @secret
      end

      def legacy_secret=(v)
        @secret = v
      end
    end)
    assert_valid! do |c|
      c.auth_methods = [:password]
      c.password_verifier = ->(u, p) { u.legacy_secret == p }
      c.password_setter = ->(u, p) { u.legacy_secret = p }
    end
  end

  def test_password_reset_token_generator_must_be_callable
    assert_invalid! do |c|
      c.auth_methods = [:password]
      c.password_reset_token_generator = nil
    end
  end

  def test_password_reset_token_finder_must_be_callable
    assert_invalid! do |c|
      c.auth_methods = [:password]
      c.password_reset_token_finder = :nope
    end
  end

  def test_before_password_reset_must_be_callable_when_provided
    assert_invalid! do |c|
      c.auth_methods = [:password]
      c.before_password_reset = :nope
    end
  end

  def test_before_password_reset_cannot_be_nil
    assert_invalid! do |c|
      c.auth_methods = [:password]
      c.before_password_reset = nil
    end
  end

  def test_password_present_predicate_must_be_callable_when_provided
    assert_invalid! do |c|
      c.auth_methods = [:password]
      c.password_present_predicate = :nope
    end
  end

  def test_password_present_predicate_cannot_be_nil
    assert_invalid! do |c|
      c.auth_methods = [:password]
      c.password_present_predicate = nil
    end
  end

  def test_boolean_normalization_for_password_reset_flags
    assert_valid! do |c|
      c.auth_methods = [:password]
      c.auto_login_after_password_reset = "yes"
      c.password_reset_enabled = nil
    end
    assert_equal true, Searls::Auth.config.auto_login_after_password_reset
    assert_equal true, Searls::Auth.config.password_reset_enabled

    assert_valid! do |c|
      c.auth_methods = [:password]
      c.password_reset_enabled = false
    end
    assert_equal false, Searls::Auth.config.password_reset_enabled
  end

  def test_numeric_options_validation_and_coercion
    # valid coercion
    assert_valid! do |c|
      c.auth_methods = [:email_link]
      c.email_otp_expiry_minutes = "15"
      c.max_allowed_email_otp_attempts = "8"
    end
    assert_equal 15, Searls::Auth.config.email_otp_expiry_minutes
    assert_equal 8, Searls::Auth.config.max_allowed_email_otp_attempts

    # invalid minutes
    err = assert_invalid! do |c|
      c.auth_methods = [:email_link]
      c.email_otp_expiry_minutes = 0
    end
    assert_includes err.message, "email_otp_expiry_minutes"

    # invalid attempts
    err = assert_invalid! do |c|
      c.auth_methods = [:email_link]
      c.email_otp_expiry_minutes = 10
      c.max_allowed_email_otp_attempts = 0
    end
    assert_includes err.message, "max_allowed_email_otp_attempts"
  end

  def test_default_redirect_path_after_login_is_alias
    assert_valid! do |c|
      c.auth_methods = [:email_link]
      c.default_redirect_path_after_login = "/hello"
    end
    assert_equal "/hello", Searls::Auth.config.redirect_path_after_login
  end

  private

  def assert_invalid!
    snapshot = Searls::Auth.config
    err = assert_raises(Searls::Auth::Error) do
      Searls::Auth.configure { |c| yield c }
    end
    err
  ensure
    # restore snapshot; configure validates on exit
    Searls::Auth.configure do |c|
      snapshot.each_pair { |k, v| c[k] = snapshot[k] }
    end
  end

  def assert_valid!
    Searls::Auth.configure { |c| yield c }
  end

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

  # Some validations only run when an ActiveModel/ActiveRecord environment is
  # present. These helpers let us trigger that code path without adding deps.
  def ensure_active_model_defined
    return nil if Object.const_defined?(:ActiveModel)
    Object.const_set(:ActiveModel, Module.new)
    -> { Object.send(:remove_const, :ActiveModel) }
  end
end
