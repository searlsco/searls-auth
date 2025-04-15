Searls::Auth::Engine.routes.draw do
  get "register", to: "registrations#show"
  post "register", to: "registrations#create"

  get "login", to: "logins#show"
  post "login", to: "logins#create"
  get "logout", to: "logins#destroy"

  get "login/verify", to: "verifications#show", as: :verify
  post "login/verify", to: "verifications#create"
  get "login/verify_token", to: "verifications#create", as: :verify_token
end
