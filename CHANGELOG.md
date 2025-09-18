## [Unreleased]

* Add password reset flow with default controllers, mailer, views, and configuration hooks
* Add `before_password_reset` hook to optionally throttle or reject reset requests
* Add configurable `password_reset_request_view` and `password_reset_edit_view` settings
* Add `password_reset_enabled` flag to disable the forgot-password link/flow when email delivery is unavailable
* Add account settings controller/view for password rotation and email changes, plus related configuration hooks

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
