## [Unreleased]

## [0.2.0] - 2025-09-11

* Add `auth_methods` configuration with default `[:email_link, :email_otp]`

## [0.1.1] - 2025-04-27

* Improve error message when token generation fails due to a token not being configured on the user model

## [0.1.0] - 2025-04-26

* Add `max_allowed_short_code_attempts` configuration, beyond which the code is erased from the session and the user needs to login again (default: 10)
* Allow configuration of flash messages
* Fix a routing error if the user is already registered

## [0.0.2] - 2025-04-16

* Little fixes. Renamed `user_name_field` to `user_name_method`

## [0.0.1] - 2025-04-15

* Initial release
