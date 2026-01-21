require "test_helper"

class LoginFlashParamSanitizationTest < ActionDispatch::IntegrationTest
  def test_sanitizes_notice_param_before_putting_it_in_flash
    html = "hi <img src=x onerror=alert(1)> there"

    get searls_auth.login_path(notice: html)

    assert_response :success
    assert_equal "hi  there", flash[:notice]
  end

  def test_sanitizes_alert_param_before_putting_it_in_flash
    html = "hi <a href=\"https://example.com\" onclick=\"alert(1)\">x</a> there"

    get searls_auth.login_path(alert: html)

    assert_response :success
    assert_equal "hi <a href=\"https://example.com\">x</a> there", flash[:alert]
  end
end
