class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :email_auth, expires_in: 30.minutes
end
