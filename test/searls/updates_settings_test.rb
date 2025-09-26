class Searls::UpdatesSettingsTest < TLDR
  def setup
    snapshot_config
  end

  def teardown
    restore_config
  end

  def test_successful_password_change_marks_result_and_sets_password
    user = FakeUser.new

    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.password_verifier = ->(candidate, password) { candidate.authenticate(password) }
      config.password_setter = ->(candidate, password) { candidate.password = password }
      config.password_present_predicate = ->(candidate) { candidate.password_digest && !candidate.password_digest.empty? }
    end

    params = {
      current_password: "old-secret",
      password: "new-secret",
      password_confirmation: "new-secret"
    }

    result = Searls::Auth::UpdatesSettings.new(
      user: user,
      params: params
    ).update

    assert result.success?, "expected settings update to succeed"
    assert result.password_changed?, "expected password_changed? flag"
    assert_equal "new-secret", user.assigned_password
  end

  def test_invalid_current_password_returns_error_and_skips_update
    user = FakeUser.new

    Searls::Auth.configure do |config|
      config.auth_methods = [:password]
      config.password_verifier = ->(candidate, password) { candidate.authenticate(password) }
      config.password_setter = ->(candidate, password) { candidate.password = password }
      config.password_present_predicate = ->(candidate) { candidate.password_digest && !candidate.password_digest.empty? }
    end

    params = {
      current_password: "totally-wrong",
      password: "new-secret",
      password_confirmation: "new-secret"
    }

    result = Searls::Auth::UpdatesSettings.new(
      user: user,
      params: params
    ).update

    refute result.success?, "expected settings update to fail"
    assert_includes Array(result.errors), "That current password doesn't match our records."
    assert_nil user.assigned_password
  end

  private

  def snapshot_config
    current = Searls::Auth.config
    @previous_config = {
      auth_methods: current.auth_methods,
      password_verifier: current.password_verifier,
      password_setter: current.password_setter,
      password_present_predicate: current.password_present_predicate
    }
  end

  def restore_config
    Searls::Auth.configure do |config|
      config.auth_methods = @previous_config[:auth_methods]
      config.password_verifier = @previous_config[:password_verifier]
      config.password_setter = @previous_config[:password_setter]
      config.password_present_predicate = @previous_config[:password_present_predicate]
    end
  end

  class FakeUser
    attr_reader :password_digest, :assigned_password

    def initialize
      @password_digest = "stored-digest"
    end

    def authenticate(candidate)
      candidate == "old-secret"
    end

    def password=(value)
      @assigned_password = value
    end

    def password_confirmation=(value)
      @assigned_password_confirmation = value
    end

    def save
      true
    end
  end
end
