Rails.application.config.after_initialize do
  Searls::Auth.configure do |config|
    # You can find the defaults in searls_auth's Searls::Auth::DEFAULT_CONFIG in 'lib/searls/auth.rb'
    #
    # Override any option with its attr_writer like:
    # config.app_name = "POSSE Party"
  end
end
