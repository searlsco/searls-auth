# searls-auth

This gem provides a Ruby on Rails engine that implements a minimal, opinionated, and pleasant email-based authentication system. It has zero other dependencies, which is the correct number of dependencies.

For a detailed walk-through with pictures and whatnot, check out this [example app README](/example/simple_app/README.md). Below you'll find the basic steps for getting started.

## Install it

Add it to your Gemfile and `bundle` it:

```ruby
gem "searls-auth"
```

## Mount it

Next, you need to mount the gem's Engine to host any of the authentication controllers and mailers.

You can mount the engine at whatever you path you like (mounting it to "/" can result in some goofy behavior, so maybe not that one). I just do "/auth" because I'm boring:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # …
  mount Searls::Auth::Engine => "/auth"
  # …
end
```

If you run your development server and visit [http://localhost:3000/auth/login](http://localhost:3000/auth/login), you should see an ugly login page. (If things look really goofy, it's because the gem defaults to your app's `"application"` layout).

## Secure it

If you've got a `User` model with an `email` attribute, you're two-thirds of the way to this thing working. All you need now is to associate [a secure token](https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html#method-i-generates_token_for) with the model named `:email_auth`.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # …
  generates_token_for :email_auth, expires_in: 30.minutes
  # …
end
```

(You can [name all these things whatever you want](#configure-it), but this is what searls-auth will assume by default.)

I'm writing this README as I add searls-auth to my new [POSSE Party](https://posseparty.com) app. As soon as I added the above line I visited [http://localhost:3000/auth/login](http://localhost:3000/auth/login), typed in my email, hit "Log in", and saw this email get sent (thanks to [letter_opener](https://github.com/ryanb/letter_opener)):

![A default searls-auth login email](https://github.com/user-attachments/assets/07114dae-a95b-49bd-ba57-92042c62c1b7)

When I pasted in the six-digit code into the (also ugly) default verification page, it auto-submitted the form. That's because my has a vanilla [import maps](https://guides.rubyonrails.org/working_with_javascript_in_rails.html#import-maps) configuration, the least-bad of the various JavaScript ordeals Rails has on offer. (Don't use import maps? Then I leave figuring out how to load the gem's [Stimulus controllers](app/javascript/controllers/searls_auth_login_controller.js) as an exercise to the reader.)

I repeated the process to ensure the "magic link" also would have worked by visiting [http://localhost:3000/auth/logout](http://localhost:3000/auth/logout) and then clicking the link.

## Configure it

Almost every user-facing thing searls-auth does is configurable, because authentication is an _intimate and precious_ thing that every application must find a way to tweak, brand, and confuse.

To configure things, create an initializer:

```
touch config/initializers/searls_auth.rb
```

And paste this into it as a starting point:

```ruby
Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    # You can find the defaults here-ish:
    # https://github.com/searlsco/searls-auth/blob/main/lib/searls/auth.rb#L14
    #
    # The expected type of each option is documented inline here-ish:
    # https://github.com/searlsco/searls-auth/blob/main/lib/searls/auth/config.rb#L3
    #
    # (Note that many options can take a proc or a value, which you may want)
    #
    # Override any option like this:
    # config.app_name = "POSSE Party"
  end
end
```
As stated in the comment above, you can find each configuration and its default value in the code.

### Choose your login methods

By default, users can log in either by clicking a magic link or by entering a 6‑digit code they receive via email. This is controlled by the `auth_methods` configuration:

```ruby
# config/initializers/searls_auth.rb
Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    # Defaults:
    config.auth_methods = [:email_link, :email_otp]

    # Link-only (no code in emails, no OTP input shown):
    # config.auth_methods = :email_link

    # Code-only (no link in emails; OTP input shown):
    # config.auth_methods = :email_otp
  end
end
```

One reason you might want to disable e-mail OTP is that it exposes your users to [a pretty easy-to-implement man-in-the-middle attack](https://blog.danielh.cc/blog/passwords).

### Email verification modes

Control whether registration triggers verification emails and whether password login requires a verified email.

```ruby
# config/initializers/searls_auth.rb
Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    # :none (default): No verification emails on registration; password login allowed immediately.
    # :optional: Send a verification email on registration, but do not block password login.
    # :required: Send a verification email on registration and block password login until verified.
    config.email_verification_mode = :none # or :optional, :required
  end
end
```

If you enable the built‑in password login (`config.auth_methods` includes `:password`), we assume your `User` model uses `has_secure_password` (or you can provide custom hooks via `password_verifier` and `password_setter`). Verification status is checked via `email_verified_at` by default and can be customized with `email_verified_predicate`/`email_verified_setter`.

### Password login

Enabling `:password` adds email+password fields to the login and registration flows. Minimal setup looks like this:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  # If you want passwords to be optional (e.g., mixing passwordless registrations),
  # use: has_secure_password validations: false

  # uncomment if enabling auth_methods :email_link or :email_otp
  # generates_token_for :email_auth, expires_in: 30.minutes
end

# db/migrate/XXXX_add_password_columns.rb
class AddPasswordColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_digest, :string
    add_column :users, :email_verified_at, :datetime
  end
end

# config/initializers/searls_auth.rb
Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    config.auth_methods = [:password] # or any combination like [:password, :email_link, :email_otp]
    config.email_verification_mode = :required # :none and :optional supported too
  end
end
```

If you already have legacy password hashing, override `password_verifier`/`password_setter` to wrap it, otherwise we'll use conventional `bcrypt` with `has_secure_password` and `password_digest` comparisons. Likewise, if email verification lives on a different column or association, use `email_verified_predicate`/`email_verified_setter` to adapt.

All successful logins still render through the same flows, so make sure your app handles `session[:user_id]` uniformly regardless of which auth method succeeded.

### Password reset

When `auth_methods` includes `:password`, the engine renders a "Forgot your password?" link beneath the login form. Clicking it walks through a two-step flow: request a reset email and then choose a new password. To enable it, make sure your `User` model issues a token named `:password_reset`. If your app cannot send email, disable the link entirely with `config.password_reset_enabled = false`.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  # You can skip this if password reset is not enabled:
  generates_token_for :password_reset, expires_in: 30.minutes

  # For allowing passwordless registrations, use:
  # has_secure_password validations: false
end
```

Adjust the expiry window by updating the `expires_in` value above or by providing a custom generator via configuration.

Need rate limiting or business rules before delivering reset emails? Return `false` or `:halt` from `before_password_reset` to silently skip sending while preserving the standard response.

By default we generate tokens via `generates_token_for`, send mail from `Searls::Auth::PasswordResetMailer`, and log the user in immediately after a successful reset. You can override any piece of that behavior:

```ruby
Searls::Auth.configure do |config|
  config.password_reset_token_generator = ->(user) { user.generate_token_for(:password_reset) }
  config.password_reset_token_finder = ->(token) { PasswordResetTokenStore.lookup(token) }
  config.password_reset_token_clearer = ->(user) { PasswordResetTokenStore.revoke(user) }
  config.auto_login_after_password_reset = false # redirect back to login instead
  config.mail_password_reset_template_path = "my_auth/password_reset_mailer"
  config.mail_password_reset_template_name = "email"
  config.before_password_reset = ->(user, params, controller) do
    PasswordResetThrottle.allow?(user_id: user&.id, ip: controller.request.remote_ip)
  end
  config.password_reset_request_view = "my_auth/password_resets/request"
  config.password_reset_edit_view = "my_auth/password_resets/edit"
  config.password_reset_enabled = false if Rails.env.development? # hide link without SMTP
end
```

### Account settings

When password authentication is enabled, searls-auth ships a default settings page at `/auth/settings/edit`. It lets a signed-in user set a password for the first time, rotate an existing password (after supplying the current one), and update their email address.

- Link to it with `searls_auth.edit_settings_path`. The template comes from `app/views/searls/auth/settings/edit.html.erb`; override it in your host app or point `config.settings_edit_view` somewhere else.
- Email edits stay disabled until the user has a password on file. Once a password exists, updating the email calls `config.email_verified_setter` with `nil` to clear any verification timestamp and issues a fresh verification email using whichever email auth methods you have enabled.
- If you track password state differently, provide your own `config.password_present_predicate`. You can also adjust the new flash messages: `flash_notice_after_settings_update`, `flash_notice_after_settings_email_verification_sent`, `flash_error_after_settings_current_password_missing`, `flash_error_after_settings_current_password_invalid`, and `flash_error_after_settings_email_not_supported`.

Want to tweak copy? Override the flash messages `flash_notice_after_password_reset_email`, `flash_notice_after_password_reset`, `flash_error_after_password_reset_token_invalid`, `flash_error_after_password_reset_password_mismatch`, and `flash_error_after_password_reset_password_blank`, or shadow the mailer templates at `app/views/searls/auth/password_reset_mailer/password_reset.html.erb` and `.text.erb`.

#### Triggering a (re)verification email

Users can request another verification email. The engine exposes a PATCH endpoint and helper you can call from your app:

```erb
<%# Anywhere in your app %>
<%= link_to "Resend verification email",
            searls_auth.resend_verification_path(email: current_user.email),
            data: { turbo_method: :patch } %>
```

This uses the same mailer and template as login emails. You can override the template in two ways:

- Configure the template path/name:

```ruby
Searls::Auth.configure do |config|
  config.mail_login_template_path = "my_auth/mailer"
  config.mail_login_template_name = "login_link"
end
```

- Or create views that shadow the engine’s defaults at `app/views/searls/auth/login_link_mailer/login_link.html.erb` and `.text.erb` in your app.

### Common configurations

| `auth_methods` | `email_verification_mode` | Behavior |
| --- | --- | --- |
| `[:email_link, :email_otp]` (default) | `:none` | Passwordless magic link + short code. Registration links go straight to the verify screen. |
| `[:password]` | `:none` | Classic email/password. No email is sent; verify routes redirect back to login. |
| `[:password, :email_link, :email_otp]` | `:optional` | Users can log in with either password or email. Registration logs the user in immediately and also emails a verification link. |
| `[:password, :email_link]` | `:required` | Registration emails a link and blocks password login until verified. Resend verification is exposed at `searls_auth.resend_verification_path`. |

In every case, `redirect_path` values are normalized to on-site URLs, so forwarding someone to login with `redirect_path: some_path` keeps the eventual redirect on your domain (cross-subdomain redirects still work via `redirect_subdomain`).

## Use it

Of course, having a user be "logged in" or not doesn't mean anything if your application doesn't do anything with the knowledge. Users that are logged in will have `session[:user_id]` set to the value of the logged-in user's ID. Logged out users won't have anything set to `session[:user_id]`. What you do with that is your job, not this gem. (Wait, after 20 years does this mean I finally understand the difference between authentication and authorization? Better late than never.)

If this is your first rodeo and you just read the previous paragraph and thought, _yeah, but now what?_, check out the tail end of the [example app README](/example/simple_app/README.md#5-require-authentication-for-appropriate-actions), which shows an approach that a lot of apps use.
