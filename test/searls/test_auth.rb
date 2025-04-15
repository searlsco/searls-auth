class Searls::TestAuth < TLDR
  def test_that_it_has_a_valid_version
    assert Gem::Version.new(::Searls::Auth::VERSION) > "0"
  end
end
