Searls::Auth::Engine.routes.draw do
  get "register", to: "registrations#show"
  post "register", to: "registrations#create"

  get "login", to: "logins#show"
  post "login", to: "logins#create"
  get "logout", to: "logins#destroy"

  get "login/verify", to: "verifications#show", as: :verify
  post "login/verify", to: "verifications#create"
  get "login/verify_token", to: "verifications#create", as: :verify_token
  match "email/resend_verification", via: [:get, :patch], to: "email_verifications#resend", as: :resend_email_verification
  get "email/pending_verification", to: "registrations#pending_email_verification", as: :pending_email_verification

  get "email/verify", to: "email_verifications#show", as: :verify_email

  resource :settings, only: [:edit, :update]

  get "password/reset", to: "requests_password_resets#show", as: :password_reset_request
  post "password/reset", to: "requests_password_resets#create"
  get "password/reset/edit", to: "resets_passwords#show", as: :password_reset_edit
  patch "password/reset", to: "resets_passwords#update", as: :password_reset_update
end
