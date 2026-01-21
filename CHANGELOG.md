## [Unreleased]

* **BREAKING:** Remove `redirect_subdomain` support in favor of `redirect_host`
* **BREAKING:** Replace `redirect_host_allowed_predicate`, `cross_domain_sso_token_generator`, and `cross_cookie_domain_predicate` with `sso_token_for_cross_domain_redirects`
* Security: Sanitize user-controlled `notice` and `alert` query params rendered on the login page to mitigate reflected XSS, while preserving safe formatting tags and links (`<a href=...>` and Turbo data attributes)
* Behavior: Disallowed tags/attributes/protocols are stripped from login `notice`/`alert` params (e.g. `<script>`, event handler attributes, `javascript:` links)

## [1.0.2] - 2025-10-13

* Ensure password resets will be delivered if user does not have a password

## [1.0.1] - 2025-10-11

* Skip database-aware configuration validations when Active Record migrations are pending

## [1.0.0] - 2025-10-04

* **BREAKING:** Rename `default_redirect_path_after_register` to `redirect_path_after_register`
* **BREAKING:** Rename `flash_notice_after_verification` to `flash_notice_after_login`
* Add password reset flow with default controllers, mailer, views, and configuration hooks
* Add `before_password_reset` hook to optionally throttle or reject reset requests
* Add configurable `password_reset_request_view` and `password_reset_edit_view` settings
* Add `password_reset_enabled` flag to disable the forgot-password link/flow when email delivery is unavailable
* Add account settings controller/view for password rotation and email changes, plus related configuration hooks
* Switch from flash[:error] to the conventional flash[:alert] (TIL, 20 years in that :alert is more common)

## [0.2.0] - 2025-09-11

* Add `auth_methods` configuration with default `[:email_link, :email_otp]`

## [0.1.1] - 2025-04-27

* Improve error message when token generation fails due to a token not being configured on the user model

## [0.1.0] - 2025-04-26

* Add `max_allowed_email_otp_attempts` configuration, beyond which the code is erased from the session and the user needs to login again (default: 10)
* Allow configuration of flash messages
* Fix a routing error if the user is already registered

## [0.0.2] - 2025-04-16

* Little fixes. Renamed `user_name_field` to `user_name_method`

## [0.0.1] - 2025-04-15

* Initial release
