module Searls
  module Auth
    Config = Struct.new(
      # Data setup
      :user_finder_by_email, # proc (email)
      :user_finder_by_id, # proc (id)
      :user_finder_by_token, # proc (token)
      :user_initializer, # proc (params)
      :user_name_method, # string
      :token_generator, # proc ()
      :token_expiry_minutes, # integer
      # Controller setup
      :preserve_session_keys_after_logout, # array of symbols
      # View setup
      :layout, # string
      :login_view, # string
      :register_view, # string
      :verify_view, # string
      :mail_layout, # string
      :mail_login_template_path, # string
      :mail_login_template_name, # string
      # Routing setup
      :redirect_path_after_register, # string or proc, all new registrations redirect here
      :default_redirect_path_after_login, # string or proc, only redirected here if redirect_path param not set
      # Hook setup
      :validate_registration, # proc (user, params, errors = []), must return an array of error messages where empty means valid
      :after_login_success, # proc (user)
      # Branding setup
      :app_name, # string
      :app_url, # string
      :support_email_address, # string
      :email_banner_image_path, # string
      :email_background_color, # string
      :email_button_color, # string
      keyword_init: true
    ) do
      # Get values from values that might be procs
      def resolve(option, *args)
        if self[option].respond_to?(:call)
          self[option].call(*args)
        else
          self[option]
        end
      end
    end
  end
end
