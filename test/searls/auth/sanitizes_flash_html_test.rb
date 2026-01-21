require "searls/auth/sanitizes_flash_html"

class Searls::Auth::SanitizesFlashHtmlTest < TLDR
  def test_allows_safe_formatting_and_links
    sanitizes_flash_html = Searls::Auth::SanitizesFlashHtml.new
    html = "hi <strong>there</strong> <a href=\"https://example.com\">link</a><br>ok"

    sanitized = sanitizes_flash_html.sanitize(html)

    assert_equal "hi <strong>there</strong> <a href=\"https://example.com\">link</a><br>ok", sanitized
  end

  def test_strips_unsafe_tags
    sanitizes_flash_html = Searls::Auth::SanitizesFlashHtml.new
    html = "hi <img src=x onerror=alert(1)> there"

    sanitized = sanitizes_flash_html.sanitize(html)

    assert_equal "hi  there", sanitized
  end

  def test_strips_unsafe_link_attributes_and_protocols
    sanitizes_flash_html = Searls::Auth::SanitizesFlashHtml.new
    html = "hi <a href=\"javascript:alert(1)\" onclick=\"alert(2)\">x</a> there"

    sanitized = sanitizes_flash_html.sanitize(html)

    assert_equal "hi <a>x</a> there", sanitized
  end

  def test_allows_turbo_method_attributes_for_links
    sanitizes_flash_html = Searls::Auth::SanitizesFlashHtml.new
    html = "<a href=\"/resend\" data-turbo-method=\"patch\">Resend</a>"

    sanitized = sanitizes_flash_html.sanitize(html)

    assert_equal "<a href=\"/resend\" data-turbo-method=\"patch\">Resend</a>", sanitized
  end
end
