class Searls::Auth::ParsesTimeSafelyTest < TLDR
  def setup
    @prev_zone = Time.zone
    Time.zone = "UTC"
    @parser = Searls::Auth::ParsesTimeSafely.new
  end

  def teardown
    Time.zone = @prev_zone
  end

  def test_returns_time_with_zone_from_string
    t = @parser.parse("2024-12-25 10:30:00")
    assert_kind_of ActiveSupport::TimeWithZone, t
    assert_equal 2024, t.year
    assert_equal 12, t.month
    assert_equal 25, t.day
    assert_equal 10, t.hour
    assert_equal "UTC", t.time_zone.name
  end

  def test_handles_time_object
    raw = Time.utc(2025, 1, 2, 3, 4, 5)
    t = @parser.parse(raw)
    assert_kind_of ActiveSupport::TimeWithZone, t
    assert_equal raw.to_i, t.to_i
  end

  def test_handles_time_with_zone
    tz = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    in_zone = tz.parse("2025-02-03 04:05:06")
    t = @parser.parse(in_zone)
    assert_equal in_zone, t
  end

  def test_handles_epoch_seconds_integer
    epoch = 1_700_000_000
    t = @parser.parse(epoch)
    assert_kind_of ActiveSupport::TimeWithZone, t
    assert_equal epoch, t.to_i
  end

  def test_returns_nil_for_blank_or_unparseable
    assert_nil @parser.parse(nil)
    assert_nil @parser.parse("")
    assert_nil @parser.parse("   ")
    assert_nil @parser.parse(Object.new)
  end
end
