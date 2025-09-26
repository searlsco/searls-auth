require "searls/auth/builds_target_redirect_url"

class Searls::Auth::BuildsTargetRedirectUrlTest < TLDR
  def setup
    @subject = Searls::Auth::BuildsTargetRedirectUrl.new
  end

  def test_a_bunch_of_urls
    assert_nil @subject.build(req, params)
    assert_equal "https://foo.posseparty.com", @subject.build(req, params(nil, "foo"))
    assert_equal "/dash", @subject.build(req, params("dash"))
    assert_equal "/dash", @subject.build(req, params("/dash"))
    assert_equal "/phish", @subject.build(req, params("https://evil.test/phish"))
    assert_nil @subject.build(req, params(nil, "app"))
    assert_equal "https://posseparty.com", @subject.build(req, params(nil, ""))
    assert_nil @subject.build(req, params(nil, "evil.com"))
    assert_equal "https://foo.posseparty.com/secret?x=1#y", @subject.build(req, params("/secret?x=1#y", "foo"))
    assert_equal "/secret?x=1#y", @subject.build(req, params("/secret?x=1#y"))
    assert_equal "/host/path", @subject.build(req, params("//host/path"))
    assert_equal "/?a=1#f", @subject.build(req, params("https://x.test?a=1#f"))
    assert_equal "https://foo.posseparty.com", @subject.build(req, params("", "foo"))
    assert_equal "/?a=1", @subject.build(req, params("?a=1"))
    assert_equal "/#f", @subject.build(req, params("#f"))
    assert_equal "/mailto:user@example.com", @subject.build(req, params("mailto:user@example.com"))
    assert_equal "/abc", @subject.build(req, params("///abc"))
    assert_equal "/dash", @subject.build(req, params("  dash  "))
    assert_equal "https://foo.posseparty.com", @subject.build(req, params(nil, "Foo"))
    assert_nil @subject.build(req, params(nil, " Foo "))
    assert_equal "https://posseparty.com", @subject.build(req, params(nil, "   "))
    assert_equal "/args", @subject.build(req, params("/args", "app"))
    assert_equal "/args", @subject.build(req, params("/args", "foo_bar"))
    assert_nil @subject.build(req, params(nil, "foo_bar"))
    assert_nil @subject.build(req_root, params(nil, ""))
    assert_equal "https://foo.posseparty.com", @subject.build(req_domain_nil, params(nil, "foo"))
    assert_equal "https://foo.localhost/p", @subject.build(req_localhost, params("/p", "foo"))
  end

  private

  FakeRequest = Struct.new(:host, :domain, :subdomain, :base_url, keyword_init: true)
  def req(**kwargs)
    FakeRequest.new(host: "app.posseparty.com",
      domain: "posseparty.com",
      subdomain: "app",
      base_url: "https://app.posseparty.com", **kwargs)
  end

  def req_root(**kwargs)
    FakeRequest.new(host: "posseparty.com",
      domain: "posseparty.com",
      subdomain: nil,
      base_url: "https://posseparty.com", **kwargs)
  end

  def req_domain_nil(**kwargs)
    FakeRequest.new(host: "app.posseparty.com",
      domain: nil,
      subdomain: "app",
      base_url: "https://app.posseparty.com", **kwargs)
  end

  def req_localhost(**kwargs)
    FakeRequest.new(host: "app.localhost",
      domain: nil,
      subdomain: "app",
      base_url: "https://app.localhost", **kwargs)
  end

  def params(path = nil, subdomain = nil)
    {
      redirect_path: path,
      redirect_subdomain: subdomain
    }.compact
  end
end
