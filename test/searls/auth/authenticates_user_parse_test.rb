class Searls::Auth::AuthenticatesUserParseTest < TLDR
  def setup
    @subject = Searls::Auth::AuthenticatesUser.new
    @prev_zone = Time.zone
    Time.zone = "UTC"
  end

  def teardown
    Time.zone = @prev_zone
  end

  def test_private_parse_accepts_multiple_input_types
    # String
    s = @subject.send(:parse_otp_timestamp, "2025-03-04 05:06:07")
    assert_kind_of ActiveSupport::TimeWithZone, s

    # Time
    t = @subject.send(:parse_otp_timestamp, Time.utc(2025, 3, 4, 5, 6, 7))
    assert_kind_of ActiveSupport::TimeWithZone, t

    # TimeWithZone
    tz = ActiveSupport::TimeZone["UTC"]
    twz = @subject.send(:parse_otp_timestamp, tz.parse("2025-03-04 05:06:07"))
    assert_kind_of ActiveSupport::TimeWithZone, twz

    # Invalid
    assert_nil @subject.send(:parse_otp_timestamp, :nope)
  end
end
