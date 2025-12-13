# TODO (bwb-adoption)

This is the remaining `searls-auth` gem work needed for grog/BWB adoption.

- [x] Add **cross-host** redirect support (not just path-only redirects)
  - [x] Accept a `redirect_host` param (optional), and reject/ignore it by default
  - [x] Add a config hook to validate hosts (e.g. `redirect_host_allowed_predicate`)
  - [x] Extend `Searls::Auth::BuildsTargetRedirectUrl` to build absolute URLs using `redirect_host` when allowed
  - [x] Preserve existing path normalization and avoid open redirects
- [x] Add **cross-cookie-domain SSO token forwarding** hook
  - [x] Provide a config hook (e.g. `cross_domain_sso_token_generator`) that can append `sso_token=...` when redirecting to another cookie domain
  - [x] Make token param name configurable (default `sso_token`)
  - [x] Provide an overridable way to decide “cross-cookie-domain” (default: registrable domain differs)
- [x] Add (or document) **logout bounce** support for multi-domain apps
  - [x] Either: first-class config for “also clear session on another domain”, or explicit docs showing how host apps can implement it
- [x] Add example app coverage
  - [x] Add integration/system tests proving `redirect_host` is rejected by default and allowed when configured
  - [x] Add a test proving SSO token appending works when enabled
- [x] Update docs
  - [x] Document `user_finder_by_email_for_registration` and the “upgrade existing non-registered user row” pattern
  - [x] Document the new cross-domain hooks and security expectations
