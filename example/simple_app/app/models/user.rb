class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :email_auth, expires_in: 30.minutes
  generates_token_for :password_reset, expires_in: 30.minutes
  has_secure_password
end
